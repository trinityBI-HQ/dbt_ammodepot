#!/bin/bash
set -euo pipefail

# Write Snowflake private key from env var to temp file
if [ -n "${SNOWFLAKE_PRIVATE_KEY:-}" ]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/dbt_rsa_key.p8
    chmod 600 /tmp/dbt_rsa_key.p8
    export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/dbt_rsa_key.p8
fi

cd /app/ammodepot

# Check source freshness (warn only, do not block build)
uv run dbt source freshness --profiles-dir . --target prod 2>&1 || echo "Warning: source freshness check failed"

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
