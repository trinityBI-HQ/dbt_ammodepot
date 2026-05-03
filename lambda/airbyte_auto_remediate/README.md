# airbyte-auto-remediate

> AWS Lambda — autonomous cancel + restart of stuck Airbyte → S3 Iceberg syncs.
> Phase 2 of [Airbyte Observability](../../docs/AIRBYTE_INCIDENT_RUNBOOK.md).

## What it does

Every 15 min on `cron(5,20,35,50)` UTC, this Lambda:

1. Reads `AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS` (Phase 1's view).
2. For every connection in `ALERT` tier (≥60 min stale by default):
   - Checks the DynamoDB circuit breaker. Skips if open.
   - If `OBSERVE_ONLY=true`: logs the would-be action and emails an `[Airbyte OBSERVE]` notification.
   - Otherwise: cancels the running Airbyte job + triggers a fresh sync via SSM.
   - Sleeps 5 min, then verifies recovery (Snowflake re-query → S3 LIST fallback).
   - Writes one row to `AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG`.
   - Publishes `[Airbyte AUTO-FIX]` or `[Airbyte ESCALATE]` to SNS → email.
   - Posts a comment to ClickUp task `86ah8bpmj`.

Phase 1's email layer (`[Airbyte WARN]` / `[Airbyte ALERT]`) is unchanged
and continues to fire independently.

## Architecture (one-liner)

```
EventBridge → Lambda → SSM → Airbyte EC2 → (5-min sleep) → Snowflake/S3 verify → SNS + ClickUp + audit row
```

Detailed design: [`.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md).

## Files

| File | Role |
|------|------|
| `main.py` | Lambda handler (single function: `handler`) |
| `pyproject.toml` | Runtime deps (boto3, snowflake-connector, requests) |
| `Dockerfile` | Container image — `public.ecr.aws/lambda/python:3.11` base |
| `ssm-payloads/cancel_and_restart.json.tmpl` | SSM `SendCommand` payload — `__CONNECTION_ID__` substituted at runtime |
| `iam-policies/lambda-trust.json` | Trust policy for the Lambda role |
| `iam-policies/lambda-execution-role.json` | Inline execution policy (least-privilege) |
| `iam-policies/eventbridge-trust.json` | Trust policy for EventBridge → Lambda |
| `iam-policies/eventbridge-rule.json` | EventBridge rule definition |
| `deploy.sh` | One-shot manual deploy (idempotent; mirrors `ecs/deploy.sh`) |

## Deploy

### First deploy (full bootstrap)

```bash
# From repo root, AFTER running streamlit_cost_monitor/setup/08_airbyte_remediation_log.sql:
cd lambda/airbyte_auto_remediate
./deploy.sh
```

This provisions ECR, SNS, DynamoDB, SSM Parameter (default `OBSERVE_ONLY=true`),
IAM role, Lambda function, EventBridge rule, and CloudWatch alarms.

The script will **warn** if the ClickUp secret is missing — create it before
the first scheduled invocation:

```bash
aws secretsmanager create-secret \
    --profile ammodepot --region us-east-1 \
    --name ammodepot/airbyte-auto-remediate/clickup \
    --description 'ClickUp personal API token for posting remediation comments' \
    --secret-string '{"token":"pk_YOUR_CLICKUP_TOKEN"}'
```

Confirm the SNS subscription email when it arrives.

### Subsequent deploys

GitHub Actions auto-builds + deploys on push to `main` (path-filtered to
`lambda/airbyte_auto_remediate/**`).
See `.github/workflows/deploy-lambda-airbyte-auto-remediate.yml`.

Manual fallback: `./deploy.sh --image-only` (skip infra provisioning).

## Operate

### Toggle observe-only

```bash
# Pause Lambda action (force observe-only):
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value true --overwrite --profile ammodepot

# Enable live action:
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value false --overwrite --profile ammodepot
```

### Reset breaker for a connection

```bash
aws dynamodb delete-item \
    --profile ammodepot \
    --table-name airbyte-auto-remediate-state \
    --key '{"connection_id":{"S":"magento_s3"}}'
```

### Disable Lambda (emergency)

```bash
aws lambda put-function-concurrency \
    --profile ammodepot \
    --function-name airbyte-auto-remediate \
    --reserved-concurrent-executions 0

# Re-enable:
aws lambda delete-function-concurrency \
    --profile ammodepot \
    --function-name airbyte-auto-remediate
```

### Tail logs

```bash
aws logs tail /aws/lambda/airbyte-auto-remediate --since 30m --profile ammodepot
```

### Inspect audit log

```sql
USE ROLE TRANSFORMER_ROLE;
SELECT
    event_time,
    connection_id,
    outcome,
    pre_staleness_min,
    post_staleness_min,
    failure_reason,
    verification_method
FROM AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG
WHERE event_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_time DESC;
```

## Cost

≤$2/mo recurring at the default 4×/hr cadence. CloudWatch billing alarm
fires at $5/mo as a hard cap. Free-tier coverage: Lambda invocations,
DynamoDB on-demand R/W (~10 ops/day), SNS publishes (<10/mo), SSM
Parameter retrievals (~3K/mo).

Snowflake compute reuses the existing `ETL_WH` (warm at the cron's
`:05/:20/:35/:50` minutes) and tags every Lambda query with
`QUERY_TAG = 'lambda:airbyte_auto_remediate'` for cost attribution.

## Troubleshooting

| Symptom | Probable cause | Fix |
|---------|----------------|-----|
| `[Airbyte ALERT]` from Phase 1 but no Lambda follow-up within 20 min | EventBridge rule disabled or Lambda concurrency capped | `aws events describe-rule --name airbyte-auto-remediate-schedule` + check `aws lambda get-function-concurrency` |
| `[Airbyte ESCALATE]` keeps recurring on same connection | Real upstream issue (Airbyte EC2 / Fishbowl source / Magento source) | Follow `docs/AIRBYTE_INCIDENT_RUNBOOK.md` (Phase 1 manual procedure) |
| ClickUp comments not appearing | Secret missing or token expired | Re-create `ammodepot/airbyte-auto-remediate/clickup` with fresh token |
| Lambda timeout (`Task timed out after 600.00 seconds`) | SSM hung mid-payload | Check Airbyte EC2 — `i-075043415ebad732f` may need a restart |

## See also

- Operator runbook: [`docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md`](../../docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md)
- Phase 1 (manual) runbook: [`docs/AIRBYTE_INCIDENT_RUNBOOK.md`](../../docs/AIRBYTE_INCIDENT_RUNBOOK.md)
- DEFINE: [`.claude/sdd/features/DEFINE_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DEFINE_AIRBYTE_AUTO_REMEDIATION.md)
- DESIGN: [`.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md)
- ClickUp task: [86ah8bpmj](https://app.clickup.com/t/86ah8bpmj)
