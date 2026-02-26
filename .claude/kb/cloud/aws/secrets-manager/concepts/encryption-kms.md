# Encryption and KMS Integration

> **Purpose**: Understand how Secrets Manager encrypts data using AWS KMS
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Every secret in Secrets Manager is encrypted at rest using an AWS KMS key. By default, the AWS-managed key `aws/secretsmanager` is used, but you can specify a customer-managed key (CMK) for cross-account access, audit separation, or compliance. Encryption is transparent — Secrets Manager handles encrypt/decrypt automatically.

## Encryption Flow

```
Store: SecretString → Secrets Manager → KMS Encrypt → Encrypted blob
Fetch: Encrypted blob → KMS Decrypt → SecretString → Application
```

## Key Types

| Key Type | ARN Pattern | Cross-Account | Cost |
|----------|-------------|---------------|------|
| AWS-managed | `aws/secretsmanager` | No | Free |
| Customer-managed (CMK) | `arn:aws:kms:...:key/...` | Yes | $1/month + API |
| Customer-managed (alias) | `alias/my-key` | Yes | $1/month + API |

## The Pattern

```python
import boto3

client = boto3.client("secretsmanager")

# Create secret with customer-managed KMS key
client.create_secret(
    Name="prod/myapp/db-credentials",
    SecretString='{"username":"admin","password":"s3cure"}',
    KmsKeyId="arn:aws:kms:us-east-1:123456789012:key/abcd-1234"
)

# Change encryption key for existing secret
client.update_secret(
    SecretId="prod/myapp/db-credentials",
    KmsKeyId="arn:aws:kms:us-east-1:123456789012:key/new-key-5678"
)
```

## KMS Key Policy for Secrets Manager

```json
{
    "Sid": "AllowSecretsManagerUse",
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
    "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:DescribeKey",
        "kms:CreateGrant"
    ],
    "Resource": "*",
    "Condition": {
        "StringEquals": {
            "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
        }
    }
}
```

## When to Use Customer-Managed Keys

- **Cross-account sharing**: AWS-managed key cannot be shared
- **Key rotation control**: Set custom rotation schedule
- **Audit separation**: Separate CloudTrail logging for key usage
- **Compliance**: Regulatory requirements for key management
- **Granular access**: Restrict who can decrypt specific secrets

## Common Mistakes

### Wrong

```python
# Using AWS-managed key for cross-account secret sharing
# This WILL NOT work — the other account cannot use aws/secretsmanager
client.create_secret(
    Name="shared/api-key",
    SecretString="sk-shared-key"
    # No KmsKeyId = uses aws/secretsmanager (default)
)
```

### Correct

```python
# Use customer-managed CMK for cross-account scenarios
client.create_secret(
    Name="shared/api-key",
    SecretString="sk-shared-key",
    KmsKeyId="arn:aws:kms:us-east-1:123456789012:key/cross-account-key"
)
```

## Related

- [Secrets Overview](../concepts/secrets-overview.md)
- [Resource Policies](../concepts/resource-policies.md)
- [Cross-Account Access](../patterns/cross-account-access.md)
