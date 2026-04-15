"""Centralized config — no hardcoded credit prices or warehouse names.

Change ``CREDIT_PRICE_USD`` here if the Snowflake contract rate changes.
"""

# Snowflake on-demand Standard credit price. Used in all cost calculations.
CREDIT_PRICE_USD: float = 3.00

# Default lookback windows (days)
DAILY_LOOKBACK_DAYS: int = 90
STORAGE_HISTORY_DAYS: int = 30

# AWS monthly trend — months of history to plot
AWS_MONTHLY_HISTORY_MONTHS: int = 6

# Anomaly detection: flag daily spend > N × 28-day rolling median
ANOMALY_MULTIPLIER: float = 2.5

# AWS Cost Explorer — services relevant to the pipeline. Filter applied
# client-side since CE doesn't support OR across service filters.
# Verified against real CE output 2026-04-08 — add new services as the
# infra evolves.
AWS_RELEVANT_SERVICES: tuple[str, ...] = (
    "Amazon Elastic Container Service",          # dbt ECS Fargate
    "Amazon EC2 Container Registry (ECR)",       # dbt image registry
    "Amazon Elastic Compute Cloud - Compute",    # Airbyte EC2
    "EC2 - Other",                               # NAT, EBS, EIP
    "Amazon Simple Storage Service",             # S3 Iceberg lakehouse
    "AWS Glue",                                  # Iceberg catalog
    "Amazon CloudWatch",                         # dbt logs + alarms
    "AWS Secrets Manager",                       # SVC_DBT private key
    "Amazon Virtual Private Cloud",              # subnets + NAT
    "AWS Key Management Service",                # encryption keys
    "Amazon Redshift",                           # SHOULD be $0 post-archive — surface it
)

# Snowflake secret name for AWS Cost Explorer creds. Must match bootstrap SQL.
AWS_SECRET_NAME: str = "aws_cost_explorer_creds"

# CloudWatch — dbt build metrics (published by ecs/entrypoint.sh)
CW_NAMESPACE: str = "AmmoDepot/dbt"
CW_METRIC_NAME: str = "BuildDurationMinutes"
CW_LOG_GROUP: str = "/ecs/ammodepot-dbt"
CW_BUILD_CEILING_MIN: float = 10.0
CW_METRIC_LOOKBACK_DAYS: int = 7

# S3 — dbt docs (single static_index.html via dbt docs generate --static)
DBT_DOCS_S3_BUCKET: str = "ammodepot-lakehouse"
DBT_DOCS_S3_KEY: str = "dbt-docs/index.html"
