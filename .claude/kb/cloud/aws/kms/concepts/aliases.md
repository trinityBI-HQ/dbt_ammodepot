# KMS Aliases

> **Purpose**: Friendly names for keys, naming conventions, and alias management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A KMS alias is a friendly name for a KMS key. Aliases simplify key management by providing human-readable references instead of UUIDs. They support key rotation via alias re-targeting, environment abstraction, and cleaner infrastructure code.

## The Pattern

```bash
# Create alias
aws kms create-alias \
  --alias-name alias/my-app/production/data-key \
  --target-key-id abcd1234-5678-90ab-cdef-example11111

# Use alias in API calls (instead of key ID)
aws kms encrypt --key-id alias/my-app/production/data-key --plaintext "secret"

# Re-target alias (for manual key rotation)
aws kms update-alias \
  --alias-name alias/my-app/production/data-key \
  --target-key-id NEW_KEY_ID
```

## Alias Rules

| Rule | Detail |
|------|--------|
| Prefix | Must start with `alias/` |
| Reserved | `alias/aws/*` is reserved for AWS-managed keys |
| Unique | Alias name must be unique per region per account |
| One-to-one | Each alias points to exactly one key |
| Many-to-one | Multiple aliases can point to the same key |
| Cross-region | Aliases are region-specific (not global) |
| Length | 1-256 characters after `alias/` prefix |
| Characters | Alphanumeric, `/`, `_`, `-` |

## Naming Conventions

```
alias/{app}/{environment}/{purpose}

Examples:
  alias/payments/prod/card-encryption
  alias/analytics/dev/data-lake-key
  alias/platform/shared/secrets-key
  alias/my-org/audit/cloudtrail-key
```

## Using Aliases in Code

```python
import boto3
kms = boto3.client("kms")

# Encrypt using alias (no need to know key ID)
response = kms.encrypt(
    KeyId="alias/my-app/prod/data-key",
    Plaintext=b"sensitive data"
)

# GenerateDataKey with alias
data_key = kms.generate_data_key(
    KeyId="alias/my-app/prod/data-key",
    KeySpec="AES_256"
)

# Describe key via alias
key_info = kms.describe_key(KeyId="alias/my-app/prod/data-key")
print(key_info["KeyMetadata"]["KeyId"])  # Actual UUID
```

## Alias-Based Key Rotation

Aliases enable seamless manual key rotation:

```
Before rotation:
  alias/my-app/prod/data-key → Key_v1

After update-alias:
  alias/my-app/prod/data-key → Key_v2

- All new encryptions use Key_v2
- Old ciphertexts still reference Key_v1 directly
- Application code doesn't change
```

## AWS-Managed Key Aliases

AWS services create aliases automatically:

| Service | Alias |
|---------|-------|
| S3 | `alias/aws/s3` |
| EBS | `alias/aws/ebs` |
| RDS | `alias/aws/rds` |
| Lambda | `alias/aws/lambda` |
| Secrets Manager | `alias/aws/secretsmanager` |
| DynamoDB | `alias/aws/dynamodb` |

These aliases point to AWS-managed keys and cannot be changed or deleted.

## Quick Reference

| Operation | CLI Command |
|-----------|-------------|
| Create | `aws kms create-alias --alias-name alias/X --target-key-id KEY_ID` |
| List | `aws kms list-aliases` |
| Re-target | `aws kms update-alias --alias-name alias/X --target-key-id NEW_KEY_ID` |
| Delete | `aws kms delete-alias --alias-name alias/X` |

## Common Mistakes

### Wrong
```python
# Hardcoding key UUIDs in application code
KEY_ID = "abcd1234-5678-90ab-cdef-example11111"
```

### Correct
```python
# Use aliases for environment-agnostic code
KEY_ALIAS = f"alias/my-app/{ENVIRONMENT}/data-key"
```

## Related

- [Key Rotation](key-rotation.md) -- alias-based manual rotation
- [Key Types](key-types.md) -- AWS-managed key aliases
- [Terraform KMS](../patterns/terraform-kms.md) -- alias management in Terraform
