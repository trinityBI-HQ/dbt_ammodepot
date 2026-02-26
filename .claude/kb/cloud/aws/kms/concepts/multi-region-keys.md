# Multi-Region Keys

> **Purpose**: Primary/replica KMS keys for cross-region encryption and disaster recovery
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Multi-region KMS keys are a set of interoperable keys in different AWS regions that share the same key material and key ID. Data encrypted in one region can be decrypted in another without cross-region API calls. This enables low-latency cross-region encryption, disaster recovery, and global applications.

## Architecture

```
Region: us-east-1 (Primary)         Region: eu-west-1 (Replica)
┌────────────────────────┐          ┌────────────────────────┐
│ mrk-abcd1234...        │  ──────> │ mrk-abcd1234...        │
│ Key Material: [same]   │  sync    │ Key Material: [same]   │
│ Key Policy: independent│          │ Key Policy: independent│
│ Aliases: independent   │          │ Aliases: independent   │
└────────────────────────┘          └────────────────────────┘
      Encrypt here ──────────────────────> Decrypt here
      (no cross-region API call needed)
```

## Creating Multi-Region Keys

```python
import boto3

# Create primary key
kms_primary = boto3.client("kms", region_name="us-east-1")
primary = kms_primary.create_key(
    Description="Multi-region primary key",
    MultiRegion=True,
    KeyUsage="ENCRYPT_DECRYPT"
)
primary_arn = primary["KeyMetadata"]["Arn"]

# Replicate to another region
kms_replica = boto3.client("kms", region_name="eu-west-1")
replica = kms_replica.replicate_key(
    KeyId=primary_arn,
    ReplicaRegion="eu-west-1",
    Description="Replica of multi-region key"
)
```

## Key Properties

| Property | Shared Across Regions | Independent Per Region |
|----------|:--------------------:|:---------------------:|
| Key ID (mrk-...) | Yes | -- |
| Key material | Yes | -- |
| Key spec & usage | Yes | -- |
| Automatic rotation | Yes (set on primary) | -- |
| Key policy | -- | Yes |
| Aliases | -- | Yes |
| Grants | -- | Yes |
| Tags | -- | Yes |
| Enabled/disabled | -- | Yes |

## Key ID Prefix

Multi-region keys always have the prefix `mrk-`:
```
Single-region: abcd1234-5678-90ab-cdef-example
Multi-region:  mrk-abcd1234-5678-90ab-cdef-example
```

## Cross-Region Encryption/Decryption

```python
# Encrypt in us-east-1
kms_east = boto3.client("kms", region_name="us-east-1")
encrypted = kms_east.encrypt(
    KeyId="mrk-abcd1234...",
    Plaintext=b"cross-region data"
)

# Decrypt in eu-west-1 using the same key ID
kms_west = boto3.client("kms", region_name="eu-west-1")
decrypted = kms_west.decrypt(
    KeyId="mrk-abcd1234...",
    CiphertextBlob=encrypted["CiphertextBlob"]
)
```

## Use Cases

| Scenario | Benefit |
|----------|---------|
| **Disaster recovery** | Decrypt backups in DR region without key replication delay |
| **Global DynamoDB tables** | Encrypt/decrypt in any region with local KMS |
| **Multi-region S3** | Cross-region replication with consistent encryption |
| **Low-latency apps** | Avoid cross-region KMS API calls |

## Rotation

- Automatic rotation is set on the **primary key only**
- New key material propagates to all replicas automatically
- Old backing keys are retained across all regions

## Promoting a Replica

If the primary region becomes unavailable:

```bash
# Promote replica to primary
aws kms update-primary-region \
  --key-id mrk-abcd1234... \
  --primary-region eu-west-1
```

The old primary becomes a replica once it comes back online.

## Common Mistakes

### Wrong
```python
# Creating separate keys per region and managing them independently
key_east = kms.create_key(Description="East key")
key_west = kms.create_key(Description="West key")
# Data encrypted with one key can't be decrypted with the other!
```

### Correct
```python
# Use multi-region key -- same key material, decrypt anywhere
key = kms.create_key(Description="Global key", MultiRegion=True)
kms.replicate_key(KeyId=key["KeyMetadata"]["Arn"], ReplicaRegion="eu-west-1")
```

## Related

- [Key Types](key-types.md) -- multi-region supported for symmetric and asymmetric
- [Key Rotation](key-rotation.md) -- rotation propagates from primary
- [Terraform KMS](../patterns/terraform-kms.md) -- multi-region key modules
