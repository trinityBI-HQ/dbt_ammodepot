#!/usr/bin/env bash
# ============================================================================
# airbyte-auto-remediate — manual deploy / one-shot bootstrap
# ============================================================================
# Idempotent — safe to re-run. Mirrors ecs/deploy.sh in style.
#
# What this provisions (all in account 746669199691, us-east-1):
#   1. ECR repo:           ammodepot/airbyte-auto-remediate
#   2. SNS topic:          airbyte-auto-remediate-events
#   3. SNS subscription:   email → recipient (operator confirms via email link)
#   4. DynamoDB table:     airbyte-auto-remediate-state (PAY_PER_REQUEST + TTL)
#   5. SSM Parameter:      /airbyte-auto-remediate/observe-only = "true"
#   6. IAM role:           svc_iac-lambda-airbyte-auto-remediate
#   7. (Operator step)     Create ClickUp secret in Secrets Manager
#   8. Lambda function:    airbyte-auto-remediate (container image)
#   9. EventBridge rule:   airbyte-auto-remediate-schedule
#  10. CloudWatch alarms:  errors + cost + stale-invocations (cost alarm requires us-east-1 billing data)
#
# Usage:
#   cd lambda/airbyte_auto_remediate
#   ./deploy.sh           # full deploy (build + push + provision)
#   ./deploy.sh --infra-only   # provision AWS resources, skip Docker
#   ./deploy.sh --image-only   # build + push image only
# ============================================================================

set -euo pipefail

# ---- Config ----------------------------------------------------------------
AWS_PROFILE="${AWS_PROFILE:-ammodepot}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="746669199691"

LAMBDA_NAME="airbyte-auto-remediate"
ECR_REPO="ammodepot/${LAMBDA_NAME}"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

SNS_TOPIC="${LAMBDA_NAME}-events"
SNS_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${ACCOUNT_ID}:${SNS_TOPIC}"
SNS_RECIPIENT="${SNS_RECIPIENT:-victor@trinitybi.com}"

DDB_TABLE="${LAMBDA_NAME}-state"

OBSERVE_PARAM_NAME="/${LAMBDA_NAME}/observe-only"

LAMBDA_ROLE_NAME="svc_iac-lambda-${LAMBDA_NAME}"
LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
LAMBDA_POLICY_NAME="${LAMBDA_ROLE_NAME}-policy"

EVENTBRIDGE_RULE="${LAMBDA_NAME}-schedule"
EVENTBRIDGE_CRON="cron(5,20,35,50 * * * ? *)"

LAMBDA_TIMEOUT_SECONDS=600
LAMBDA_MEMORY_MB=512

CLICKUP_TASK_ID="${CLICKUP_TASK_ID:-86ah8bpmj}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAM_DIR="${SCRIPT_DIR}/iam-policies"

AWS=(aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}")

# ---- Mode ------------------------------------------------------------------
MODE="full"
case "${1:-}" in
    --infra-only) MODE="infra" ;;
    --image-only) MODE="image" ;;
    "") MODE="full" ;;
    *) echo "Usage: $0 [--infra-only|--image-only]" >&2; exit 2 ;;
esac

log()  { echo -e "\033[1;36m[deploy]\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m   $*"; }
ok()   { echo -e "\033[1;32m[ok]\033[0m     $*"; }

# ---- ECR -------------------------------------------------------------------
ensure_ecr() {
    log "ECR: ensuring repo ${ECR_REPO}"
    if ! "${AWS[@]}" ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
        "${AWS[@]}" ecr create-repository \
            --repository-name "${ECR_REPO}" \
            --image-scanning-configuration scanOnPush=true >/dev/null
        ok "ECR: created ${ECR_REPO}"
    else
        ok "ECR: ${ECR_REPO} already exists"
    fi
}

build_and_push_image() {
    log "Docker: building ${ECR_URI}:latest"
    "${AWS[@]}" ecr get-login-password \
        | docker login --username AWS --password-stdin "${ECR_URI%/*}"

    local tag
    tag="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || echo manual)"

    # Lambda requires OCI v1 manifests; Docker 25+ defaults to v1.1 with
    # provenance attestations that Lambda rejects. Force a Lambda-compatible
    # image: linux/amd64 platform, no provenance, no SBOM.
    docker buildx build \
        --platform linux/amd64 \
        --provenance=false \
        --sbom=false \
        --output=type=docker \
        -t "${ECR_URI}:${tag}" \
        -t "${ECR_URI}:latest" \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "${SCRIPT_DIR}"

    docker push "${ECR_URI}:${tag}"
    docker push "${ECR_URI}:latest"
    ok "Docker: pushed ${ECR_URI}:${tag} and :latest"
}

# ---- SNS -------------------------------------------------------------------
ensure_sns() {
    log "SNS: ensuring topic ${SNS_TOPIC}"
    "${AWS[@]}" sns create-topic --name "${SNS_TOPIC}" >/dev/null
    ok "SNS: topic ${SNS_TOPIC_ARN} ready"

    local subs
    subs="$("${AWS[@]}" sns list-subscriptions-by-topic --topic-arn "${SNS_TOPIC_ARN}" \
        --query "Subscriptions[?Endpoint=='${SNS_RECIPIENT}'].SubscriptionArn" --output text)"

    if [[ -z "${subs}" || "${subs}" == "None" ]]; then
        "${AWS[@]}" sns subscribe \
            --topic-arn "${SNS_TOPIC_ARN}" \
            --protocol email \
            --notification-endpoint "${SNS_RECIPIENT}" >/dev/null
        warn "SNS: subscription created — ${SNS_RECIPIENT} must click confirmation email!"
    else
        ok "SNS: ${SNS_RECIPIENT} already subscribed"
    fi
}

# ---- DynamoDB --------------------------------------------------------------
ensure_dynamodb() {
    log "DynamoDB: ensuring table ${DDB_TABLE}"
    if ! "${AWS[@]}" dynamodb describe-table --table-name "${DDB_TABLE}" >/dev/null 2>&1; then
        "${AWS[@]}" dynamodb create-table \
            --table-name "${DDB_TABLE}" \
            --attribute-definitions AttributeName=connection_id,AttributeType=S \
            --key-schema AttributeName=connection_id,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST >/dev/null
        log "DynamoDB: created ${DDB_TABLE}, waiting for ACTIVE..."
        "${AWS[@]}" dynamodb wait table-exists --table-name "${DDB_TABLE}"
    fi

    local ttl_status
    ttl_status="$("${AWS[@]}" dynamodb describe-time-to-live --table-name "${DDB_TABLE}" \
        --query "TimeToLiveDescription.TimeToLiveStatus" --output text 2>/dev/null || echo NONE)"

    if [[ "${ttl_status}" != "ENABLED" && "${ttl_status}" != "ENABLING" ]]; then
        "${AWS[@]}" dynamodb update-time-to-live \
            --table-name "${DDB_TABLE}" \
            --time-to-live-specification "Enabled=true,AttributeName=ttl" >/dev/null
        ok "DynamoDB: TTL enabled on attribute 'ttl'"
    else
        ok "DynamoDB: TTL already enabled"
    fi
}

# ---- SSM Parameter ---------------------------------------------------------
ensure_observe_only_param() {
    log "SSM: ensuring ${OBSERVE_PARAM_NAME} = 'true' (observe-only on first deploy)"
    if "${AWS[@]}" ssm get-parameter --name "${OBSERVE_PARAM_NAME}" >/dev/null 2>&1; then
        local cur
        cur="$("${AWS[@]}" ssm get-parameter --name "${OBSERVE_PARAM_NAME}" \
            --query "Parameter.Value" --output text)"
        ok "SSM: ${OBSERVE_PARAM_NAME} already set to '${cur}' (NOT modifying — operator-controlled)"
    else
        "${AWS[@]}" ssm put-parameter \
            --name "${OBSERVE_PARAM_NAME}" \
            --type String \
            --value "true" \
            --description "When 'true', Lambda logs decisions but does not call SSM SendCommand. Toggle to 'false' AFTER ≥1 week of observe-only soak." >/dev/null
        ok "SSM: ${OBSERVE_PARAM_NAME} created with value 'true'"
    fi
}

# ---- IAM role --------------------------------------------------------------
ensure_iam_role() {
    log "IAM: ensuring role ${LAMBDA_ROLE_NAME}"
    if ! "${AWS[@]}" iam get-role --role-name "${LAMBDA_ROLE_NAME}" >/dev/null 2>&1; then
        "${AWS[@]}" iam create-role \
            --role-name "${LAMBDA_ROLE_NAME}" \
            --assume-role-policy-document "file://${IAM_DIR}/lambda-trust.json" \
            --description "Lambda execution role for airbyte-auto-remediate (Phase 2)" >/dev/null
        ok "IAM: created role ${LAMBDA_ROLE_NAME}"
    else
        "${AWS[@]}" iam update-assume-role-policy \
            --role-name "${LAMBDA_ROLE_NAME}" \
            --policy-document "file://${IAM_DIR}/lambda-trust.json" >/dev/null
        ok "IAM: role ${LAMBDA_ROLE_NAME} trust policy synced"
    fi

    "${AWS[@]}" iam put-role-policy \
        --role-name "${LAMBDA_ROLE_NAME}" \
        --policy-name "${LAMBDA_POLICY_NAME}" \
        --policy-document "file://${IAM_DIR}/lambda-execution-role.json" >/dev/null
    ok "IAM: inline policy ${LAMBDA_POLICY_NAME} synced"
}

# ---- ClickUp secret guard --------------------------------------------------
guard_clickup_secret() {
    log "Secrets Manager: checking ammodepot/airbyte-auto-remediate/clickup"
    if ! "${AWS[@]}" secretsmanager describe-secret \
            --secret-id "ammodepot/airbyte-auto-remediate/clickup" >/dev/null 2>&1; then
        warn "ClickUp secret missing — operator must create it before Lambda is invoked:"
        echo
        echo "    aws secretsmanager create-secret \\"
        echo "        --profile ${AWS_PROFILE} --region ${AWS_REGION} \\"
        echo "        --name ammodepot/airbyte-auto-remediate/clickup \\"
        echo "        --description 'ClickUp personal API token for posting remediation comments' \\"
        echo "        --secret-string '{\"token\":\"pk_YOUR_CLICKUP_TOKEN\"}'"
        echo
        warn "Generate a token at: https://app.clickup.com/${CLICKUP_TASK_ID}/v/settings/apps"
        warn "Lambda will fail closed (ClickUp post will log warning but not crash) until secret exists."
    else
        ok "Secrets Manager: ClickUp secret already present"
    fi
}

# ---- Lambda ----------------------------------------------------------------
ensure_lambda() {
    log "Lambda: ensuring function ${LAMBDA_NAME}"
    if ! "${AWS[@]}" lambda get-function --function-name "${LAMBDA_NAME}" >/dev/null 2>&1; then
        "${AWS[@]}" lambda create-function \
            --function-name "${LAMBDA_NAME}" \
            --package-type Image \
            --code "ImageUri=${ECR_URI}:latest" \
            --role "${LAMBDA_ROLE_ARN}" \
            --timeout "${LAMBDA_TIMEOUT_SECONDS}" \
            --memory-size "${LAMBDA_MEMORY_MB}" \
            --architectures x86_64 \
            --environment "Variables={SNS_TOPIC_ARN=${SNS_TOPIC_ARN},DDB_TABLE=${DDB_TABLE},CLICKUP_TASK_ID=${CLICKUP_TASK_ID},SECRET_SNOWFLAKE=ammodepot/dbt/snowflake,SECRET_CLICKUP=ammodepot/airbyte-auto-remediate/clickup,SNOWFLAKE_ACCOUNT=iwb48385.us-east-1,SNOWFLAKE_USER=SVC_DBT,SNOWFLAKE_ROLE=TRANSFORMER_ROLE,SNOWFLAKE_WAREHOUSE=ETL_WH,SNOWFLAKE_DATABASE=AD_ANALYTICS}" \
            --description "Phase 2 of Airbyte Observability — autonomous cancel + restart on ALERT-tier breaches" >/dev/null
        log "Lambda: created — waiting for ACTIVE..."
        "${AWS[@]}" lambda wait function-active --function-name "${LAMBDA_NAME}"
        ok "Lambda: created"
    else
        "${AWS[@]}" lambda update-function-code \
            --function-name "${LAMBDA_NAME}" \
            --image-uri "${ECR_URI}:latest" \
            --publish >/dev/null
        "${AWS[@]}" lambda wait function-updated --function-name "${LAMBDA_NAME}"
        "${AWS[@]}" lambda update-function-configuration \
            --function-name "${LAMBDA_NAME}" \
            --timeout "${LAMBDA_TIMEOUT_SECONDS}" \
            --memory-size "${LAMBDA_MEMORY_MB}" \
            --environment "Variables={SNS_TOPIC_ARN=${SNS_TOPIC_ARN},DDB_TABLE=${DDB_TABLE},CLICKUP_TASK_ID=${CLICKUP_TASK_ID},SECRET_SNOWFLAKE=ammodepot/dbt/snowflake,SECRET_CLICKUP=ammodepot/airbyte-auto-remediate/clickup,SNOWFLAKE_ACCOUNT=iwb48385.us-east-1,SNOWFLAKE_USER=SVC_DBT,SNOWFLAKE_ROLE=TRANSFORMER_ROLE,SNOWFLAKE_WAREHOUSE=ETL_WH,SNOWFLAKE_DATABASE=AD_ANALYTICS}" >/dev/null
        "${AWS[@]}" lambda wait function-updated --function-name "${LAMBDA_NAME}"
        ok "Lambda: code + config updated"
    fi

    "${AWS[@]}" logs put-retention-policy \
        --log-group-name "/aws/lambda/${LAMBDA_NAME}" \
        --retention-in-days 14 2>/dev/null || true
}

# ---- EventBridge -----------------------------------------------------------
ensure_eventbridge() {
    log "EventBridge: ensuring rule ${EVENTBRIDGE_RULE}"
    "${AWS[@]}" events put-rule \
        --name "${EVENTBRIDGE_RULE}" \
        --schedule-expression "${EVENTBRIDGE_CRON}" \
        --state ENABLED \
        --description "Synced to dbt cron — Lambda's Snowflake query lands on warm ETL_WH" >/dev/null
    ok "EventBridge: rule ${EVENTBRIDGE_RULE} synced (${EVENTBRIDGE_CRON})"

    "${AWS[@]}" events put-targets \
        --rule "${EVENTBRIDGE_RULE}" \
        --targets "Id=lambda-target,Arn=arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}" >/dev/null
    ok "EventBridge: target = Lambda ${LAMBDA_NAME}"

    if ! "${AWS[@]}" lambda get-policy --function-name "${LAMBDA_NAME}" 2>/dev/null \
            | grep -q "${EVENTBRIDGE_RULE}-invoke" ; then
        "${AWS[@]}" lambda add-permission \
            --function-name "${LAMBDA_NAME}" \
            --statement-id "${EVENTBRIDGE_RULE}-invoke" \
            --action "lambda:InvokeFunction" \
            --principal events.amazonaws.com \
            --source-arn "arn:aws:events:${AWS_REGION}:${ACCOUNT_ID}:rule/${EVENTBRIDGE_RULE}" >/dev/null
        ok "Lambda: granted invoke permission to EventBridge rule"
    else
        ok "Lambda: invoke permission for EventBridge already present"
    fi
}

# ---- CloudWatch alarms -----------------------------------------------------
ensure_cloudwatch_alarms() {
    log "CloudWatch: ensuring alarms"

    "${AWS[@]}" cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_NAME}-errors" \
        --alarm-description "Lambda Errors >= 1 in any 5-min window" \
        --metric-name Errors --namespace AWS/Lambda \
        --statistic Sum --period 300 --evaluation-periods 1 --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --treat-missing-data notBreaching \
        --dimensions "Name=FunctionName,Value=${LAMBDA_NAME}" \
        --alarm-actions "${SNS_TOPIC_ARN}"
    ok "CloudWatch: alarm ${LAMBDA_NAME}-errors synced"

    "${AWS[@]}" cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_NAME}-stale-invocations" \
        --alarm-description "No Lambda invocations in 30 min — EventBridge may be disabled" \
        --metric-name Invocations --namespace AWS/Lambda \
        --statistic Sum --period 1800 --evaluation-periods 1 --threshold 1 \
        --comparison-operator LessThanThreshold \
        --treat-missing-data breaching \
        --dimensions "Name=FunctionName,Value=${LAMBDA_NAME}" \
        --alarm-actions "${SNS_TOPIC_ARN}"
    ok "CloudWatch: alarm ${LAMBDA_NAME}-stale-invocations synced"

    if "${AWS[@]}" --region us-east-1 cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_NAME}-cost" \
        --alarm-description "Estimated charges > \$5/mo (covers Lambda + DynamoDB + SNS + Secrets + ECR)" \
        --metric-name EstimatedCharges --namespace AWS/Billing \
        --statistic Maximum --period 21600 --evaluation-periods 1 --threshold 5 \
        --comparison-operator GreaterThanThreshold \
        --treat-missing-data notBreaching \
        --dimensions "Name=Currency,Value=USD" \
        --alarm-actions "${SNS_TOPIC_ARN}" 2>/dev/null; then
        ok "CloudWatch: alarm ${LAMBDA_NAME}-cost synced"
    else
        warn "CloudWatch: cost alarm couldn't be set (Billing metrics require root account opt-in). Skipping."
    fi
}

# ---- Main ------------------------------------------------------------------
case "${MODE}" in
    image)
        ensure_ecr
        build_and_push_image
        ;;
    infra)
        ensure_ecr
        ensure_sns
        ensure_dynamodb
        ensure_observe_only_param
        ensure_iam_role
        guard_clickup_secret
        ensure_eventbridge
        ensure_cloudwatch_alarms
        ;;
    full)
        ensure_ecr
        build_and_push_image
        ensure_sns
        ensure_dynamodb
        ensure_observe_only_param
        ensure_iam_role
        guard_clickup_secret
        ensure_lambda
        ensure_eventbridge
        ensure_cloudwatch_alarms
        ;;
esac

echo
ok "Done."
echo
echo "Next steps for the operator:"
echo "  1. Confirm the SNS subscription email link sent to ${SNS_RECIPIENT}"
echo "  2. Create the ClickUp secret (see warning above) if not already present"
echo "  3. Run the Snowflake bootstrap: streamlit_cost_monitor/setup/08_airbyte_remediation_log.sql"
echo "  4. Tail logs:        aws logs tail /aws/lambda/${LAMBDA_NAME} --since 30m --profile ${AWS_PROFILE}"
echo "  5. After ≥1 week observe-only soak, flip to live:"
echo "       aws ssm put-parameter --name ${OBSERVE_PARAM_NAME} \\"
echo "         --value false --overwrite --profile ${AWS_PROFILE}"
