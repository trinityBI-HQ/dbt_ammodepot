# Secrets Overview

> **Purpose**: Understand secret structure, types, and lifecycle in AWS Secrets Manager
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A secret in AWS Secrets Manager consists of encrypted secret data (string or binary) plus metadata for management. Secrets Manager encrypts data at rest using KMS, supports automatic rotation via Lambda, and provides fine-grained IAM access control. Secrets are region-specific but can be replicated cross-region.

## Secret Structure

A secret contains:

| Component | Description |
|-----------|-------------|
| **Name** | Unique identifier (path-style: `prod/db/credentials`) |
| **ARN** | `arn:aws:secretsmanager:<region>:<account>:secret:<name>-<random>` |
| **SecretString** | UTF-8 text (typically JSON), max 64KB |
| **SecretBinary** | Binary data, max 64KB |
| **Description** | Human-readable description |
| **KmsKeyId** | KMS key for encryption (default: `aws/secretsmanager`) |
| **Tags** | Key-value pairs for organization and ABAC |
| **VersionId** | UUID for each version |
| **VersionStages** | Labels like AWSCURRENT, AWSPREVIOUS |

## Secret Types

```python
import json

# Key-value (most common for database credentials)
db_secret = json.dumps({
    "username": "admin",
    "password": "s3cure!Pass",
    "engine": "postgres",
    "host": "db.example.com",
    "port": 5432,
    "dbname": "myapp"
})

# Plain string (API keys, tokens)
api_secret = "sk-abc123xyz789"

# Binary (certificates, keystores)
# Use SecretBinary parameter instead of SecretString
```

## Secret Naming Conventions

Use hierarchical path-style names for organization:

```
<environment>/<service>/<secret-type>
prod/myapp/db-credentials
dev/myapp/api-key
shared/certificates/tls-cert
```

## Lifecycle

1. **Create** - Store initial secret value with optional KMS key
2. **Retrieve** - Applications fetch via `GetSecretValue` (use caching)
3. **Update** - New version created, AWSCURRENT moves automatically
4. **Rotate** - Lambda function creates new credential and updates secret
5. **Delete** - Soft delete with recovery window (7-30 days), then permanent

## Quotas

| Resource | Limit |
|----------|-------|
| Secret value size | 64 KB |
| Secret name length | 256 characters |
| Secrets per account per region | 500,000 |
| Versions per secret | ~100 |
| Labels per version | 20 |
| Resource policy size | 20 KB |

## Common Mistakes

### Wrong

```python
# Hardcoding secrets in source code
DB_PASSWORD = "my-secret-password"
```

### Correct

```python
import boto3, json

client = boto3.client("secretsmanager")
response = client.get_secret_value(SecretId="prod/myapp/db-credentials")
creds = json.loads(response["SecretString"])
```

## Related

- [Versioning](../concepts/versioning.md)
- [Rotation](../concepts/rotation.md)
- [Boto3 Integration](../patterns/boto3-integration.md)
