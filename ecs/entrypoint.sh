#!/bin/bash
set -euo pipefail

# Write Snowflake private key from env var to temp file
if [ -n "${SNOWFLAKE_PRIVATE_KEY:-}" ]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/dbt_rsa_key.p8
    chmod 600 /tmp/dbt_rsa_key.p8
    export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/dbt_rsa_key.p8
fi

cd /app/ammodepot

# Refresh UNMANAGED Iceberg tables in LAKEHOUSE_LANDING in parallel BEFORE dbt
# starts. This used to be a dbt on-run-start hook but dbt runs hooks serially
# via the master connection, costing 45-90s warm and 3-5min cold. The Python
# script uses 8 worker threads and is 4-6x faster. See ecs/refresh_iceberg.py
# for the rationale.
#
# Fail fast: if Iceberg refresh errors out, dbt would silently build from a
# stale catalog and ship wrong numbers. Better to fail the build and page.
echo "=== Iceberg Refresh ==="
ICEBERG_START=$(date +%s)
uv run python /app/refresh_iceberg.py
ICEBERG_DURATION=$(($(date +%s) - ICEBERG_START))
echo "ICEBERG_REFRESH_SECONDS=${ICEBERG_DURATION}"

# Check source freshness (results saved to JSON, stderr suppressed to avoid
# triggering CloudWatch alarm on ERROR STALE — the metric filter matches [31mERROR)
echo "=== Source Freshness Check ==="
uv run dbt source freshness --profiles-dir . --target prod --output json --output-path /tmp/freshness.json 2>/dev/null || echo "FRESHNESS_CHECK_COMPLETED_WITH_WARNINGS"

# Track build duration
START_TIME=$(date +%s)
uv run dbt build --profiles-dir . --target prod
EXIT_CODE=$?
END_TIME=$(date +%s)

# Run snapshots after build so they capture fresh model output.
# Runs every cycle but check strategy only writes rows when data changes.
# Snapshot failures are non-fatal — don't override the build exit code.
if [ $EXIT_CODE -eq 0 ]; then
    uv run dbt snapshot --profiles-dir . --target prod || echo "Warning: snapshot step failed"
fi
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
