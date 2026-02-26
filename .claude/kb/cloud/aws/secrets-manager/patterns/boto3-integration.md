# Boto3 Integration Pattern

> **Purpose**: Production-ready Python patterns for creating, retrieving, updating, and deleting secrets
> **MCP Validated**: 2026-02-19

## When to Use

- Python applications needing runtime secret retrieval
- Lambda functions accessing database credentials
- Scripts managing secrets programmatically
- Batch operations across multiple secrets

## Implementation

```python
import boto3
import json
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class SecretsManagerClient:
    """Wrapper for AWS Secrets Manager operations."""

    def __init__(self, region_name: str = "us-east-1"):
        self.client = boto3.client("secretsmanager", region_name=region_name)

    def create_secret(
        self,
        name: str,
        secret_value: dict,
        description: str = "",
        kms_key_id: str | None = None,
        tags: list[dict] | None = None,
    ) -> str:
        """Create a new secret with JSON value."""
        params = {
            "Name": name,
            "SecretString": json.dumps(secret_value),
            "Description": description,
        }
        if kms_key_id:
            params["KmsKeyId"] = kms_key_id
        if tags:
            params["Tags"] = tags

        response = self.client.create_secret(**params)
        logger.info("Created secret: %s", response["ARN"])
        return response["ARN"]

    def get_secret(self, secret_id: str) -> dict:
        """Retrieve and parse a JSON secret."""
        try:
            response = self.client.get_secret_value(SecretId=secret_id)
            return json.loads(response["SecretString"])
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code == "ResourceNotFoundException":
                logger.error("Secret %s not found", secret_id)
            elif code == "DecryptionFailureException":
                logger.error("KMS decryption failed for %s", secret_id)
            raise

    def update_secret(self, secret_id: str, secret_value: dict) -> str:
        """Update secret value (creates new version)."""
        response = self.client.put_secret_value(
            SecretId=secret_id,
            SecretString=json.dumps(secret_value),
        )
        logger.info("Updated secret %s, version: %s", secret_id, response["VersionId"])
        return response["VersionId"]

    def delete_secret(self, secret_id: str, recovery_days: int = 7) -> None:
        """Soft-delete a secret with recovery window."""
        self.client.delete_secret(
            SecretId=secret_id,
            RecoveryWindowInDays=recovery_days,
        )
        logger.info("Scheduled deletion for %s in %d days", secret_id, recovery_days)

    def batch_get_secrets(self, name_prefix: str) -> list[dict]:
        """Retrieve multiple secrets by name prefix."""
        response = self.client.batch_get_secret_value(
            Filters=[{"Key": "name", "Values": [name_prefix]}]
        )
        return [json.loads(s["SecretString"]) for s in response["SecretValues"]]
```

## Example Usage

```python
sm = SecretsManagerClient(region_name="us-east-1")

# Create
sm.create_secret(
    name="prod/myapp/db-credentials",
    secret_value={"username": "admin", "password": "s3cure!", "host": "db.example.com"},
    tags=[{"Key": "Environment", "Value": "prod"}],
)

# Retrieve
creds = sm.get_secret("prod/myapp/db-credentials")
conn_string = f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}/mydb"

# Update
sm.update_secret("prod/myapp/db-credentials", {**creds, "password": "n3wP@ss!"})

# Batch get all prod secrets
all_prod = sm.batch_get_secrets("prod/")
```

## Error Handling Reference

| Exception | Cause | Action |
|-----------|-------|--------|
| `ResourceNotFoundException` | Secret doesn't exist | Check name/ARN |
| `DecryptionFailureException` | KMS key issue | Check key policy |
| `InvalidRequestException` | Secret pending deletion | Restore or wait |
| `InvalidParameterException` | Bad input | Validate parameters |
| `LimitExceededException` | API throttled | Implement backoff |

## See Also

- [Caching Pattern](../patterns/caching-pattern.md)
- [Secrets Overview](../concepts/secrets-overview.md)
