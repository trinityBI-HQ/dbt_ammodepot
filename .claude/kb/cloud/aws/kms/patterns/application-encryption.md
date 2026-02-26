# Application Encryption Pattern

> **Purpose**: Encrypt/decrypt data in application code using Boto3 and AWS Encryption SDK
> **MCP Validated**: 2026-02-19

## When to Use

- Encrypting application secrets, tokens, or PII before storage
- Client-side encryption before uploading to S3 or databases
- Encrypting data in Lambda functions or microservices
- Field-level encryption in databases

## Direct Encryption (< 4 KB)

For small payloads (passwords, tokens, config values):

```python
import boto3
import base64

kms = boto3.client("kms")
KEY_ALIAS = "alias/my-app/prod/data-key"

def encrypt_secret(plaintext: str) -> str:
    """Encrypt a small secret directly with KMS."""
    response = kms.encrypt(
        KeyId=KEY_ALIAS,
        Plaintext=plaintext.encode("utf-8"),
        EncryptionContext={"purpose": "api-token"}
    )
    return base64.b64encode(response["CiphertextBlob"]).decode("utf-8")

def decrypt_secret(ciphertext_b64: str) -> str:
    """Decrypt a KMS-encrypted secret."""
    response = kms.decrypt(
        CiphertextBlob=base64.b64decode(ciphertext_b64),
        EncryptionContext={"purpose": "api-token"}
    )
    return response["Plaintext"].decode("utf-8")
```

**Important**: The `EncryptionContext` must match between encrypt and decrypt calls.

## Envelope Encryption (> 4 KB)

For larger payloads (files, documents, database fields):

```python
import boto3
from cryptography.fernet import Fernet
import base64

kms = boto3.client("kms")

def encrypt_large_data(key_id: str, data: bytes, context: dict) -> dict:
    """Encrypt data using envelope encryption."""
    # Generate data key
    dk = kms.generate_data_key(
        KeyId=key_id,
        KeySpec="AES_256",
        EncryptionContext=context
    )

    # Encrypt locally
    fernet = Fernet(base64.urlsafe_b64encode(dk["Plaintext"]))
    encrypted_data = fernet.encrypt(data)

    # Wipe plaintext key from memory
    del dk["Plaintext"]

    return {
        "encrypted_key": base64.b64encode(dk["CiphertextBlob"]).decode(),
        "encrypted_data": base64.b64encode(encrypted_data).decode(),
        "context": context
    }

def decrypt_large_data(payload: dict) -> bytes:
    """Decrypt envelope-encrypted data."""
    # Decrypt data key via KMS
    dk = kms.decrypt(
        CiphertextBlob=base64.b64decode(payload["encrypted_key"]),
        EncryptionContext=payload["context"]
    )

    # Decrypt data locally
    fernet = Fernet(base64.urlsafe_b64encode(dk["Plaintext"]))
    return fernet.decrypt(base64.b64decode(payload["encrypted_data"]))
```

## AWS Encryption SDK (Production)

For production workloads, use the official SDK which handles envelope encryption, key caching, and algorithm selection:

```python
import aws_encryption_sdk
from aws_encryption_sdk.identifiers import CommitmentPolicy

client = aws_encryption_sdk.EncryptionSDKClient(
    commitment_policy=CommitmentPolicy.REQUIRE_ENCRYPT_REQUIRE_DECRYPT
)

kms_provider = aws_encryption_sdk.StrictAwsKmsMasterKeyProvider(
    key_ids=["arn:aws:kms:us-east-1:123456789012:key/KEY_ID"]
)

# Encrypt
ciphertext, enc_header = client.encrypt(
    source=b"sensitive data",
    key_provider=kms_provider,
    encryption_context={"purpose": "user-pii"}
)

# Decrypt
plaintext, dec_header = client.decrypt(
    source=ciphertext,
    key_provider=kms_provider
)
```

## Encryption Context

A map of key-value pairs that provides additional authenticated data (AAD):

```python
context = {
    "user_id": "user-12345",
    "table": "customers",
    "field": "ssn"
}
# Context is logged in CloudTrail (non-secret metadata)
# Must be provided at both encrypt and decrypt time
```

| Property | Detail |
|----------|--------|
| Logged in CloudTrail | Yes -- use for audit trails |
| Must match on decrypt | Yes -- mismatch causes error |
| Should contain secrets? | No -- it's not encrypted |
| Max size | 8 KB total |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `KeySpec` | `AES_256` | Data key spec for GenerateDataKey |
| `EncryptionContext` | None | Optional but strongly recommended |
| `GrantTokens` | None | Use when accessing via grants |
| Encryption SDK `frame_length` | 4096 | Frame size for streaming encryption |

## Example Usage: Lambda with KMS

```python
import os
import boto3

kms = boto3.client("kms")
ENCRYPTED_DB_PASSWORD = os.environ["ENCRYPTED_DB_PASSWORD"]

# Decrypt at cold start (cache the result)
DB_PASSWORD = kms.decrypt(
    CiphertextBlob=base64.b64decode(ENCRYPTED_DB_PASSWORD),
    EncryptionContext={"service": "my-lambda", "env": "prod"}
)["Plaintext"].decode("utf-8")

def handler(event, context):
    # Use DB_PASSWORD (decrypted once, reused across invocations)
    pass
```

## See Also

- [Envelope Encryption](../concepts/envelope-encryption.md) -- pattern theory
- [Key Types](../concepts/key-types.md) -- symmetric vs asymmetric for encryption
- [Service Integration](service-integration.md) -- built-in encryption for AWS services
