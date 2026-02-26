# Key Rotation

> **Purpose**: Automatic and manual key rotation strategies, backing keys, and imported material
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Key rotation replaces the cryptographic material of a KMS key while keeping the same key ID and alias. AWS handles re-encryption transparently for automatic rotation. Previously encrypted data remains decryptable because KMS retains all old backing keys.

## Automatic Rotation

Enable for symmetric, customer-managed keys with KMS-generated material:

```bash
# Enable automatic rotation
aws kms enable-key-rotation --key-id KEY_ID

# Verify rotation status
aws kms get-key-rotation-status --key-id KEY_ID

# Configure rotation period (default 365 days, range 90-2560)
aws kms rotate-key-on-demand --key-id KEY_ID
```

```python
import boto3
kms = boto3.client("kms")

kms.enable_key_rotation(KeyId="arn:aws:kms:us-east-1:123:key/KEY_ID")

status = kms.get_key_rotation_status(KeyId="arn:aws:kms:us-east-1:123:key/KEY_ID")
print(f"Rotation enabled: {status['KeyRotationEnabled']}")
```

### How Automatic Rotation Works

```
Key ID: abcd1234-5678-...  (never changes)
Alias: alias/my-app-key    (never changes)

Year 1:  BackingKey_v1  ← current (used for new encryptions)
Year 2:  BackingKey_v2  ← current (new encryptions)
         BackingKey_v1  ← retained (decrypts old data)
Year 3:  BackingKey_v3  ← current
         BackingKey_v2  ← retained
         BackingKey_v1  ← retained
```

- Key ID and ARN remain the same
- Aliases continue pointing to the same key
- Old data is decryptable without re-encryption
- New encryptions use the latest backing key

## Rotation Support by Key Type

| Key Type | Auto Rotation | On-Demand Rotation | Manual Rotation |
|----------|:------------:|:------------------:|:---------------:|
| Symmetric (KMS-generated) | Yes | Yes | Yes |
| Symmetric (imported material) | No | Yes (Jun 2025) | Yes (re-import) |
| Asymmetric | No | No | Yes (create new key) |
| HMAC | No | No | Yes (create new key) |
| ML-DSA (post-quantum) | No | No | Yes (create new key) |
| AWS-managed keys | Yes (yearly, mandatory) | N/A | N/A |
| Multi-region keys | Yes (primary only) | Yes | Yes |

## Manual Rotation

For key types that don't support automatic rotation, use alias-based manual rotation:

```bash
# Step 1: Create new key
NEW_KEY=$(aws kms create-key --description "App key v2" --query 'KeyMetadata.KeyId' --output text)

# Step 2: Update alias to point to new key
aws kms update-alias --alias-name alias/my-app-key --target-key-id $NEW_KEY

# Step 3: Keep old key enabled for decrypting existing data
# Step 4: After migration, disable (then eventually delete) old key
```

**Important**: The alias update is atomic. All new encryptions immediately use the new key. Old ciphertexts still reference the original key ID, so the old key must remain enabled for decryption.

## On-Demand Rotation for Imported Keys (BYOK) -- Jun 2025

As of June 2025, keys with imported material support on-demand rotation:

```bash
# Rotate imported key material on-demand
aws kms rotate-key-on-demand --key-id KEY_ID
```

- Key ARN, alias, and key ID remain unchanged
- Old backing keys are retained for decrypting existing data
- No need to create a new key and update aliases
- Import new key material after triggering on-demand rotation

### Legacy Manual Rotation (Alias-Based)

For environments not yet using on-demand rotation:

1. Create a new key with imported material
2. Update the alias to point to the new key
3. Keep old key for decrypting existing data
4. Optionally set `valid_to` expiration on old key material

## Rotation Best Practices

| Practice | Recommendation |
|----------|---------------|
| Frequency | Annual for most workloads (default) |
| Compliance | Some standards require 90-day rotation |
| Imported keys | Use on-demand rotation (Jun 2025) or alias-based manual rotation |
| Cost | Old backing keys are free; only active key costs $1/mo |
| Audit | CloudTrail logs rotation events automatically |

## Common Mistakes

### Wrong
```bash
# Deleting old key immediately after rotation
aws kms schedule-key-deletion --key-id OLD_KEY --pending-window-in-days 7
# Existing encrypted data becomes permanently unreadable!
```

### Correct
```bash
# Disable old key after confirming all data has been re-encrypted
# or keep it as long as old ciphertext may need decrypting
aws kms disable-key --key-id OLD_KEY
# Only delete after full data migration + verification
```

## Related

- [Key Types](key-types.md) -- rotation varies by key type
- [Multi-Region Keys](multi-region-keys.md) -- rotation on primary propagates
- [Terraform KMS](../patterns/terraform-kms.md) -- managing rotation in code
