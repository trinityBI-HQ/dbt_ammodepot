# Multi-Region Replication

> **Purpose**: Understand cross-region secret replication for HA and disaster recovery
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Secrets Manager can replicate secrets to multiple AWS regions, creating read-only replicas that stay in sync with the primary. Replicas use their own KMS key for encryption in each region. This enables multi-region applications to read secrets locally with low latency and provides disaster recovery capability.

## Replication Architecture

```
Primary Region (us-east-1)          Replica (us-west-2)
┌─────────────────────┐             ┌─────────────────────┐
│ Secret: prod/db-cred│────sync────▶│ Secret: prod/db-cred│
│ KMS: key-east       │             │ KMS: key-west       │
│ Read/Write          │             │ Read-Only            │
└─────────────────────┘             └─────────────────────┘
                                    Replica (eu-west-1)
                                    ┌─────────────────────┐
                                    │ Secret: prod/db-cred│
                                    │ KMS: key-eu          │
                                    │ Read-Only            │
                                    └─────────────────────┘
```

## The Pattern

```python
import boto3

client = boto3.client("secretsmanager", region_name="us-east-1")

# Create secret with replicas
client.create_secret(
    Name="prod/myapp/db-credentials",
    SecretString='{"username":"admin","password":"s3cure"}',
    AddReplicaRegions=[
        {
            "Region": "us-west-2",
            "KmsKeyId": "arn:aws:kms:us-west-2:123456789012:key/west-key"
        },
        {
            "Region": "eu-west-1",
            "KmsKeyId": "arn:aws:kms:eu-west-1:123456789012:key/eu-key"
        }
    ]
)

# Add replica to existing secret
client.replicate_secret_to_regions(
    SecretId="prod/myapp/db-credentials",
    AddReplicaRegions=[
        {"Region": "ap-southeast-1"}  # Uses aws/secretsmanager key
    ]
)

# Remove replica
client.remove_regions_from_replication(
    SecretId="prod/myapp/db-credentials",
    RemoveReplicaRegions=["ap-southeast-1"]
)
```

## Replica Behavior

| Aspect | Primary | Replica |
|--------|---------|---------|
| Read | Yes | Yes |
| Write | Yes | No |
| Rotation | Configured here | Synced from primary |
| KMS key | Per-region | Per-region (independent) |
| Delete | Deletes all replicas | Use `remove_regions` |
| Promote | N/A | Promote to standalone |

## Promote Replica to Standalone

```python
# In disaster recovery: promote replica to independent secret
replica_client = boto3.client("secretsmanager", region_name="us-west-2")
replica_client.stop_replication_to_replica(
    SecretId="prod/myapp/db-credentials"
)
# Now us-west-2 secret is independent, writable
```

## Terraform Example

```hcl
resource "aws_secretsmanager_secret" "db_creds" {
  name       = "prod/myapp/db-credentials"
  kms_key_id = aws_kms_key.primary.arn

  replica {
    region     = "us-west-2"
    kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/west-key"
  }

  replica {
    region = "eu-west-1"
  }
}
```

## Common Mistakes

### Wrong

```python
# Trying to write to a replica directly
west_client = boto3.client("secretsmanager", region_name="us-west-2")
west_client.put_secret_value(SecretId="prod/db-cred", SecretString="new")
# ERROR: cannot update a replicated secret in a replica region
```

### Correct

```python
# Always write to the primary region
east_client = boto3.client("secretsmanager", region_name="us-east-1")
east_client.put_secret_value(SecretId="prod/db-cred", SecretString="new")
# Replicas auto-sync
```

## Related

- [Secrets Overview](../concepts/secrets-overview.md)
- [Encryption and KMS](../concepts/encryption-kms.md)
- [Terraform Setup](../patterns/terraform-setup.md)
