# Lambda Rotation Pattern

> **Purpose**: Implement automatic secret rotation using Lambda functions
> **MCP Validated**: 2026-02-19

## When to Use

- Database credentials need periodic rotation
- API keys have expiration policies
- Compliance requires credential rotation (SOC2, PCI-DSS)
- Zero-downtime credential updates required

## Implementation

```python
"""Lambda rotation function for PostgreSQL database credentials."""
import boto3
import json
import logging
import os
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sm_client = boto3.client("secretsmanager")


def lambda_handler(event: dict, context) -> None:
    """Entry point for rotation Lambda — dispatches to step functions."""
    step = event["Step"]
    secret_id = event["SecretId"]
    token = event["ClientRequestToken"]

    metadata = sm_client.describe_secret(SecretId=secret_id)
    versions = metadata["VersionIdsToStages"]
    if token not in versions:
        raise ValueError(f"Token {token} not found in secret versions")
    if "AWSCURRENT" in versions[token]:
        logger.info("Secret %s version %s already AWSCURRENT", secret_id, token)
        return

    dispatch = {
        "createSecret": create_secret,
        "setSecret": set_secret,
        "testSecret": test_secret,
        "finishSecret": finish_secret,
    }
    dispatch[step](secret_id, token)


def create_secret(secret_id: str, token: str) -> None:
    """Generate new password and store as AWSPENDING."""
    current = sm_client.get_secret_value(
        SecretId=secret_id, VersionStage="AWSCURRENT"
    )
    creds = json.loads(current["SecretString"])

    # Generate new password
    new_password = sm_client.get_random_password(
        PasswordLength=32,
        ExcludeCharacters="/@\"'\\"
    )["RandomPassword"]

    creds["password"] = new_password
    sm_client.put_secret_value(
        SecretId=secret_id,
        ClientRequestToken=token,
        SecretString=json.dumps(creds),
        VersionStages=["AWSPENDING"],
    )
    logger.info("createSecret: stored new password as AWSPENDING")


def set_secret(secret_id: str, token: str) -> None:
    """Apply the new password to the database."""
    pending = json.loads(
        sm_client.get_secret_value(
            SecretId=secret_id, VersionId=token, VersionStage="AWSPENDING"
        )["SecretString"]
    )
    current = json.loads(
        sm_client.get_secret_value(
            SecretId=secret_id, VersionStage="AWSCURRENT"
        )["SecretString"]
    )

    conn = psycopg2.connect(
        host=current["host"],
        port=current.get("port", 5432),
        user=current["username"],
        password=current["password"],
        dbname=current.get("dbname", "postgres"),
    )
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(
            "ALTER USER %s WITH PASSWORD %s",
            (pending["username"], pending["password"]),
        )
    conn.close()
    logger.info("setSecret: applied new password to database")


def test_secret(secret_id: str, token: str) -> None:
    """Verify the new credentials work."""
    pending = json.loads(
        sm_client.get_secret_value(
            SecretId=secret_id, VersionId=token, VersionStage="AWSPENDING"
        )["SecretString"]
    )
    conn = psycopg2.connect(
        host=pending["host"],
        port=pending.get("port", 5432),
        user=pending["username"],
        password=pending["password"],
        dbname=pending.get("dbname", "postgres"),
    )
    conn.close()
    logger.info("testSecret: new credentials verified")


def finish_secret(secret_id: str, token: str) -> None:
    """Promote AWSPENDING to AWSCURRENT."""
    metadata = sm_client.describe_secret(SecretId=secret_id)
    current_version = next(
        v for v, stages in metadata["VersionIdsToStages"].items()
        if "AWSCURRENT" in stages
    )
    sm_client.update_secret_version_stage(
        SecretId=secret_id,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    logger.info("finishSecret: promoted %s to AWSCURRENT", token)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `RotationLambdaARN` | Required | ARN of the rotation Lambda |
| `AutomaticallyAfterDays` | 30 | Rotation frequency |
| `ScheduleExpression` | `rate(30 days)` | Cron or rate expression |
| `Duration` | `None` | Max rotation window (e.g., `2h`) |

## Network Requirements

The rotation Lambda needs network access to both:
1. **Secrets Manager API** — via VPC endpoint or internet
2. **Target service** (database) — via VPC/security group

```
Lambda (VPC) ──▶ VPC Endpoint (secretsmanager) ──▶ Secrets Manager API
     │
     └──▶ RDS Security Group ──▶ PostgreSQL
```

## See Also

- [Rotation Concept](../concepts/rotation.md)
- [Boto3 Integration](../patterns/boto3-integration.md)
- [Terraform Setup](../patterns/terraform-setup.md)
