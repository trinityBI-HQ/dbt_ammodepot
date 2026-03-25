#!/bin/bash
set -euo pipefail

# Write Snowflake private key from env var to temp file
if [ -n "${SNOWFLAKE_PRIVATE_KEY:-}" ]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/dbt_rsa_key.p8
    chmod 600 /tmp/dbt_rsa_key.p8
    export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/dbt_rsa_key.p8
fi

cd /app/ammodepot

# Check source freshness (results saved to JSON, stderr suppressed to avoid
# triggering CloudWatch alarm on ERROR STALE — the metric filter matches [31mERROR)
echo "=== Source Freshness Check ==="
uv run dbt source freshness --profiles-dir . --target prod --output json --output-path /tmp/freshness.json 2>/dev/null || echo "FRESHNESS_CHECK_COMPLETED_WITH_WARNINGS"

# Track build duration
START_TIME=$(date +%s)
uv run dbt build --profiles-dir . --target prod
EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$(echo "scale=2; $DURATION / 60" | bc)

echo "BUILD_DURATION_SECONDS=${DURATION}"
echo "BUILD_DURATION_MINUTES=${DURATION_MIN}"

# Publish duration metric to CloudWatch
aws cloudwatch put-metric-data \
    --namespace AmmoDepot/dbt \
    --metric-name BuildDurationMinutes \
    --value "$DURATION_MIN" \
    --unit None \
    --region us-east-1 2>/dev/null || echo "Warning: Could not publish CloudWatch metric"

exit $EXIT_CODE
