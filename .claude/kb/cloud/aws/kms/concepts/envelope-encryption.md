# Envelope Encryption

> **Purpose**: Data key pattern for encrypting payloads larger than 4 KB
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

KMS keys can only encrypt up to 4 KB directly. For larger data, use envelope encryption: generate a data key with KMS, encrypt data locally with the plaintext data key, then store the encrypted data key alongside the encrypted data. This approach is fast (local encryption), scalable, and keeps the KMS key secure.

## The Pattern

```
┌─────────────────────────────────────────┐
│  KMS (cloud)                            │
│  ┌─────────┐    GenerateDataKey         │
│  │ KMS Key │ ────────────────────┐      │
│  └─────────┘                     │      │
│                    ┌─────────────┴────┐  │
│                    │ Plaintext Key    │  │
│                    │ Encrypted Key    │  │
│                    └─────────────────-┘  │
└─────────────────────────────────────────┘
         │                    │
         ▼ (plaintext)        ▼ (encrypted)
┌──────────────────┐  ┌───────────────────┐
│ Encrypt data     │  │ Store alongside   │
│ locally (AES)    │  │ encrypted data    │
│ Then DISCARD     │  │                   │
│ plaintext key    │  │ [enc_key|enc_data]│
└──────────────────┘  └───────────────────┘
```

## Encryption Flow

```python
import boto3
from cryptography.fernet import Fernet
import base64

kms = boto3.client("kms")

def encrypt_data(key_id: str, plaintext: bytes) -> tuple[bytes, bytes]:
    """Encrypt data using envelope encryption."""
    # Step 1: Generate data key from KMS
    response = kms.generate_data_key(KeyId=key_id, KeySpec="AES_256")
    plaintext_key = response["Plaintext"]        # 32 bytes
    encrypted_key = response["CiphertextBlob"]    # Encrypted by KMS

    # Step 2: Encrypt data locally with plaintext key
    fernet_key = base64.urlsafe_b64encode(plaintext_key)
    encrypted_data = Fernet(fernet_key).encrypt(plaintext)

    # Step 3: Discard plaintext key (only keep encrypted version)
    del plaintext_key, fernet_key

    return encrypted_key, encrypted_data
```

## Decryption Flow

```python
def decrypt_data(encrypted_key: bytes, encrypted_data: bytes) -> bytes:
    """Decrypt data using envelope encryption."""
    # Step 1: Decrypt the data key via KMS
    response = kms.decrypt(CiphertextBlob=encrypted_key)
    plaintext_key = response["Plaintext"]

    # Step 2: Decrypt data locally
    fernet_key = base64.urlsafe_b64encode(plaintext_key)
    plaintext = Fernet(fernet_key).decrypt(encrypted_data)

    del plaintext_key, fernet_key
    return plaintext
```

## GenerateDataKey vs GenerateDataKeyWithoutPlaintext

| API | Returns | Use When |
|-----|---------|----------|
| `GenerateDataKey` | Plaintext + encrypted key | Encrypting immediately |
| `GenerateDataKeyWithoutPlaintext` | Encrypted key only | Pre-generating for later use |

## Why Envelope Encryption?

| Benefit | Explanation |
|---------|-------------|
| **Performance** | Encrypt locally (fast AES) instead of sending data to KMS |
| **Size limit** | KMS Encrypt API limited to 4 KB; data keys handle any size |
| **Network** | Only small key material crosses the network, not bulk data |
| **Security** | KMS key never leaves AWS; plaintext data key exists only briefly |
| **Audit** | CloudTrail logs GenerateDataKey/Decrypt but not the data itself |

## AWS Encryption SDK

For production use, the AWS Encryption SDK handles envelope encryption automatically:

```python
import aws_encryption_sdk
from aws_encryption_sdk.identifiers import CommitmentPolicy

client = aws_encryption_sdk.EncryptionSDKClient(
    commitment_policy=CommitmentPolicy.REQUIRE_ENCRYPT_REQUIRE_DECRYPT
)
kms_provider = aws_encryption_sdk.StrictAwsKmsMasterKeyProvider(
    key_ids=["arn:aws:kms:us-east-1:123456789012:key/KEY_ID"]
)

ciphertext, header = client.encrypt(source=plaintext, key_provider=kms_provider)
decrypted, header = client.decrypt(source=ciphertext, key_provider=kms_provider)
```

## Common Mistakes

### Wrong
```python
# Storing plaintext data key alongside encrypted data
storage = {"key": plaintext_key, "data": encrypted_data}  # Key exposed!
```

### Correct
```python
# Store ONLY the encrypted data key; discard plaintext immediately
storage = {"enc_key": encrypted_key, "enc_data": encrypted_data}
```

## Related

- [Key Types](key-types.md) -- symmetric keys for data key generation
- [Application Encryption](../patterns/application-encryption.md) -- production patterns
- [S3 Encryption](../patterns/s3-encryption.md) -- S3 handles envelope encryption internally
