"""Centralized config — no hardcoded credit prices or warehouse names.

Change ``CREDIT_PRICE_USD`` here if the Snowflake contract rate changes.
"""

# Snowflake on-demand Standard credit price. Used in all cost calculations.
CREDIT_PRICE_USD: float = 3.00

# Default lookback windows (days)
DAILY_LOOKBACK_DAYS: int = 90
TOP_QUERIES_LOOKBACK_DAYS: int = 7
STORAGE_HISTORY_DAYS: int = 30

# Anomaly detection: flag daily spend > N × 28-day rolling median
ANOMALY_MULTIPLIER: float = 2.5

# AWS Cost Explorer — services relevant to the pipeline. Filter applied
# client-side since CE doesn't support OR across service filters.
AWS_RELEVANT_SERVICES: tuple[str, ...] = (
    "Amazon Elastic Container Service",
    "Amazon EC2 Container Registry (ECR)",
    "Amazon Elastic Compute Cloud - Compute",
    "EC2 - Other",
    "Amazon Simple Storage Service",
    "AWS Glue",
    "Amazon CloudWatch",
    "AWS Secrets Manager",
    "Amazon Virtual Private Cloud",
    "AWS Key Management Service",
    "AmazonCloudWatch",
)

# Snowflake secret name for AWS Cost Explorer creds. Must match bootstrap SQL.
AWS_SECRET_NAME: str = "aws_cost_explorer_creds"
