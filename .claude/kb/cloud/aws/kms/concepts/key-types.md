# KMS Key Types

> **Purpose**: Symmetric, asymmetric, HMAC keys and ownership categories
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

AWS KMS supports three key structures (symmetric, asymmetric, HMAC) and three ownership levels (AWS-owned, AWS-managed, customer-managed). Choosing the right combination determines cost, control, rotation behavior, and integration options.

## Key Structures

### Symmetric (Default)

- **Algorithm**: AES-256-GCM
- Encrypts and decrypts with the same key
- Key never leaves KMS unencrypted
- Can encrypt up to 4 KB directly; use data keys for larger payloads
- Most common choice for envelope encryption

```python
import boto3
kms = boto3.client("kms")
response = kms.create_key(
    Description="Application encryption key",
    KeyUsage="ENCRYPT_DECRYPT",
    KeySpec="SYMMETRIC_DEFAULT"  # AES-256-GCM
)
key_id = response["KeyMetadata"]["KeyId"]
```

### Asymmetric

- Public/private key pair; public key is downloadable
- **RSA**: encrypt/decrypt or sign/verify (2048, 3072, 4096)
- **ECC**: sign/verify only (P-256, P-384, P-521, secp256k1)
- Private key never leaves KMS; public key can be used outside AWS

```python
# Create RSA signing key
response = kms.create_key(
    Description="API signing key",
    KeyUsage="SIGN_VERIFY",
    KeySpec="RSA_2048"
)
# Download public key for external verification
pub_key = kms.get_public_key(KeyId=response["KeyMetadata"]["KeyId"])
```

### Post-Quantum ML-DSA (Jun 2025)

- **Algorithm**: ML-DSA (Module-Lattice Digital Signature Algorithm), FIPS 204
- Sign/verify only; resistant to quantum computing attacks
- **Key specs**: ML_DSA_44, ML_DSA_65, ML_DSA_87 (increasing security levels)
- Private key never leaves KMS; public key is downloadable
- Use for long-term digital signatures that must remain secure against future quantum threats

```python
# Create post-quantum signing key
response = kms.create_key(
    Description="Post-quantum signing key",
    KeyUsage="SIGN_VERIFY",
    KeySpec="ML_DSA_65"
)
```

### HMAC

- Generate and verify hash-based message authentication codes
- Key specs: HMAC_224, HMAC_256, HMAC_384, HMAC_512
- Use for API request signing, token validation, data integrity

## Ownership Categories

| Category | Who Creates | Who Manages | Key Policy | Cost | Rotation |
|----------|-----------|-------------|------------|------|----------|
| **AWS-owned** | AWS | AWS | Not visible | Free | Automatic (opaque) |
| **AWS-managed** | AWS | AWS | Viewable, not editable | Per-use only | Annual (automatic) |
| **Customer-managed** | You | You | Full control | $1/mo + per-use | Configurable |

### AWS-Owned Keys
- Used transparently by services (e.g., DynamoDB default encryption)
- No visibility into key ID or policy; fully managed by AWS
- No CloudTrail logging of key usage

### AWS-Managed Keys
- Created automatically when a service first needs encryption (e.g., `aws/s3`)
- Visible in console with `aws/service-name` alias
- CloudTrail logs key usage; you cannot modify key policy
- Rotated automatically every year

### Customer-Managed Keys
- Full control: key policy, grants, rotation, enable/disable, deletion
- Can be shared cross-account via key policy
- Support aliases, tags, multi-region replication
- **Recommended** for production workloads needing audit control

## Quick Reference

| Decision | Choose |
|----------|--------|
| Default encryption, no special needs | AWS-managed |
| Need cross-account access | Customer-managed |
| Need custom rotation schedule | Customer-managed |
| Need to sign data outside AWS | Asymmetric (RSA/ECC) |
| Quantum-resistant signatures | ML-DSA (post-quantum) |
| Data integrity verification | HMAC |
| Cost-sensitive, low control needs | AWS-owned (service default) |

## Common Mistakes

### Wrong
```python
# Using Encrypt API for large files (> 4 KB)
kms.encrypt(KeyId=key_id, Plaintext=large_file_bytes)  # Will fail!
```

### Correct
```python
# Use envelope encryption for large payloads
data_key = kms.generate_data_key(KeyId=key_id, KeySpec="AES_256")
# Encrypt locally with data_key["Plaintext"], store data_key["CiphertextBlob"]
```

## Related

- [Envelope Encryption](envelope-encryption.md) -- using data keys for large payloads
- [Key Policies](key-policies.md) -- access control for customer-managed keys
- [S3 Encryption](../patterns/s3-encryption.md) -- SSE-S3 vs SSE-KMS
