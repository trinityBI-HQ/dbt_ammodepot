# Resources

> **Purpose**: Configurable connections to external services with dependency injection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Resources are configurable objects that provide access to external services like databases, APIs, and cloud storage. They enable dependency injection, making assets testable by swapping production resources for mocks. Resources are defined once in the Definitions object and automatically injected into assets that request them by name.

## The Pattern

```python
import dagster as dg
from dagster import ConfigurableResource
import boto3

class S3Resource(ConfigurableResource):
    """Resource for interacting with AWS S3."""

    bucket_name: str
    region: str = "us-east-1"

    def get_client(self):
        return boto3.client("s3", region_name=self.region)

    def upload_file(self, key: str, data: bytes) -> str:
        client = self.get_client()
        client.put_object(Bucket=self.bucket_name, Key=key, Body=data)
        return f"s3://{self.bucket_name}/{key}"

    def download_file(self, key: str) -> bytes:
        client = self.get_client()
        response = client.get_object(Bucket=self.bucket_name, Key=key)
        return response["Body"].read()

# Use resource in asset
@dg.asset
def processed_data(context: dg.AssetExecutionContext, s3: S3Resource) -> str:
    """Process data and upload to S3."""
    data = b"processed content"
    path = s3.upload_file("output/data.parquet", data)
    context.log.info(f"Uploaded to {path}")
    return path

# Register resource in Definitions
defs = dg.Definitions(
    assets=[processed_data],
    resources={
        "s3": S3Resource(
            bucket_name=dg.EnvVar("S3_BUCKET"),
            region="us-west-2",
        ),
    },
)
```

## Quick Reference

| Feature | Usage | Notes |
|---------|-------|-------|
| `ConfigurableResource` | Base class for resources | Pydantic-based configuration |
| `EnvVar("NAME")` | Environment variable | Shows in UI, evaluated at runtime |
| Nested resources | Shared configuration | Common credentials pattern |

## Environment Variables

```python
class DatabaseResource(ConfigurableResource):
    host: str
    port: int = 5432
    user: str
    password: str  # Use EnvVar when instantiating

# EnvVar provides visibility in UI
defs = dg.Definitions(
    resources={
        "database": DatabaseResource(
            host=dg.EnvVar("DB_HOST"),
            user=dg.EnvVar("DB_USER"),
            password=dg.EnvVar("DB_PASSWORD"),
        ),
    },
)
```

## Nested Resources Pattern

```python
class CloudCredentials(ConfigurableResource):
    """Shared credentials for cloud services."""
    project_id: str
    service_account_key: str

class BigQueryResource(ConfigurableResource):
    credentials: CloudCredentials
    dataset: str

    def query(self, sql: str):
        # Use self.credentials.project_id
        pass

class GCSResource(ConfigurableResource):
    credentials: CloudCredentials
    bucket: str

# Shared credentials across resources
creds = CloudCredentials(
    project_id=dg.EnvVar("GCP_PROJECT"),
    service_account_key=dg.EnvVar("GCP_KEY"),
)

defs = dg.Definitions(
    resources={
        "bigquery": BigQueryResource(credentials=creds, dataset="analytics"),
        "gcs": GCSResource(credentials=creds, bucket="data-lake"),
    },
)
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Hardcoded credentials
class BadResource(ConfigurableResource):
    password: str = "secret123"  # Never do this!
```

### Correct

```python
# Correct: Use EnvVar for all secrets
defs = dg.Definitions(
    resources={
        "db": DatabaseResource(
            password=dg.EnvVar("DB_PASSWORD"),
        ),
    },
)
```

## Related

- [io-managers](../concepts/io-managers.md)
- [definitions](../concepts/definitions.md)
- [testing-assets](../patterns/testing-assets.md)
