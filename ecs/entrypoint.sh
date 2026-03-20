#!/bin/bash
set -euo pipefail

# Write Snowflake private key from env var to temp file
if [ -n "${SNOWFLAKE_PRIVATE_KEY:-}" ]; then
    echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/dbt_rsa_key.p8
    chmod 600 /tmp/dbt_rsa_key.p8
    export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/dbt_rsa_key.p8
fi

cd /app/ammodepot
exec uv run dbt build --profiles-dir . --target prod
