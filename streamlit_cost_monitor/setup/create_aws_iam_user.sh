#!/usr/bin/env bash
# ============================================================================
# create_aws_iam_user.sh — provision svc_snowflake_costs in the client AWS account
# ============================================================================
#
# Creates an IAM user with an inline read-only Cost Explorer policy and
# generates a fresh access-key pair. The key is PRINTED ONCE to stdout.
# Copy it into setup/02_create_secret.sql immediately and run that file.
#
# Idempotent:
#   - If the user exists, creation is skipped.
#   - Policy is re-applied (PutUserPolicy upserts).
#   - Access key is created only if --new-key is passed OR no keys exist.
#
# Usage:
#   ./create_aws_iam_user.sh                # first-time run
#   ./create_aws_iam_user.sh --new-key      # rotate (deletes existing keys first)
#
# Requires: aws CLI with `--profile ammodepot` configured.
# ============================================================================

set -euo pipefail

PROFILE="ammodepot"
USER_NAME="svc_snowflake_costs"
POLICY_NAME="CostExplorerReadOnly"
POLICY_FILE="$(dirname "$0")/aws_cost_explorer_policy.json"

rotate=false
if [[ "${1:-}" == "--new-key" ]]; then
  rotate=true
fi

aws_cmd() {
  aws --profile "$PROFILE" "$@"
}

echo "▶ Checking if IAM user ${USER_NAME} exists..."
if aws_cmd iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
  echo "   User already exists."
else
  echo "   Creating user..."
  aws_cmd iam create-user \
    --user-name "$USER_NAME" \
    --tags Key=Purpose,Value="Snowflake cost monitor EAI" \
           Key=ManagedBy,Value="streamlit_cost_monitor/setup/create_aws_iam_user.sh"
fi

echo "▶ Applying inline policy ${POLICY_NAME}..."
aws_cmd iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${POLICY_FILE}"

if $rotate; then
  echo "▶ Rotating: deleting existing access keys..."
  existing_keys=$(aws_cmd iam list-access-keys --user-name "$USER_NAME" \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  for k in $existing_keys; do
    echo "   Deleting $k"
    aws_cmd iam delete-access-key --user-name "$USER_NAME" --access-key-id "$k"
  done
fi

existing=$(aws_cmd iam list-access-keys --user-name "$USER_NAME" \
  --query 'length(AccessKeyMetadata)' --output text)

if [[ "$existing" == "0" ]]; then
  echo "▶ Creating access key..."
  key_json=$(aws_cmd iam create-access-key --user-name "$USER_NAME")
  access_key=$(echo "$key_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["AccessKey"]["AccessKeyId"])')
  secret_key=$(echo "$key_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["AccessKey"]["SecretAccessKey"])')

  cat <<EOF

============================================================================
  ACCESS KEY CREATED  —  save this NOW, it will not be shown again
============================================================================

  Access Key ID:     ${access_key}
  Secret Access Key: ${secret_key}

  Paste into streamlit_cost_monitor/setup/02_create_secret.sql:

      '{"access_key":"${access_key}","secret_key":"${secret_key}"}'

  Then run 02_create_secret.sql in Snowflake as ACCOUNTADMIN and clear
  your shell history (unset HISTFILE; clear).

============================================================================
EOF
else
  echo "▶ Existing access key detected — skipping creation."
  echo "   Use '--new-key' to rotate."
fi

echo "✔ Done."
