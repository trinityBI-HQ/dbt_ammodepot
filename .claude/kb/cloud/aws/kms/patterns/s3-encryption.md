# S3 Encryption Pattern

> **Purpose**: Server-side encryption options for S3 using KMS keys
> **MCP Validated**: 2026-02-19

## When to Use

- Encrypting data at rest in S3 buckets
- Compliance requirements mandating encryption (HIPAA, PCI-DSS, SOC2)
- Cross-account data sharing with encryption control
- Enforcing encryption on all uploads

## Encryption Options

| Method | Key Management | Key Visibility | Cost | Audit |
|--------|---------------|----------------|------|-------|
| SSE-S3 | AWS manages entirely | No key access | Free | Limited |
| SSE-KMS (AWS-managed) | AWS-managed key `aws/s3` | Viewable | Per-request | CloudTrail |
| SSE-KMS (Customer-managed) | You manage | Full control | $1/mo + per-request | Full CloudTrail |
| SSE-C | You provide per request | You store key | Free | None in KMS |
| Client-side | You encrypt before upload | You manage | Free | Your responsibility |

## SSE-KMS with Customer-Managed Key (Recommended)

### Bucket Configuration

```python
import boto3

s3 = boto3.client("s3")

# Set default encryption on bucket
s3.put_bucket_encryption(
    Bucket="my-data-bucket",
    ServerSideEncryptionConfiguration={
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms",
                "KMSMasterKeyID": "arn:aws:kms:us-east-1:123456789012:key/KEY_ID"
            },
            "BucketKeyEnabled": True  # Reduces KMS API calls by 99%
        }]
    }
)
```

### Enforce Encryption on Upload

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-data-bucket/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyWrongKey",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-data-bucket/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption-aws-kms-key-id": "arn:aws:kms:us-east-1:123:key/KEY_ID"
        }
      }
    }
  ]
}
```

## S3 Bucket Key

Bucket Key reduces KMS costs by caching a bucket-level key derived from your KMS key:

```
Without Bucket Key: Each object → KMS API call (expensive at scale)
With Bucket Key:    Bucket-level key cached → fewer KMS calls (99% reduction)
```

- Enable with `BucketKeyEnabled: True`
- CloudTrail shows bucket ARN instead of object ARN as context
- Compatible with SSE-KMS only

## IAM Permissions for SSE-KMS

The uploading/downloading principal needs both S3 and KMS permissions:

```json
{
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-data-bucket/*"
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/KEY_ID"
    }
  ]
}
```

## Cross-Account Access with SSE-KMS

For another account to read encrypted objects:
1. S3 bucket policy grants cross-account S3 access
2. KMS key policy grants cross-account `kms:Decrypt`
3. Requesting account's IAM policy allows `s3:GetObject` and `kms:Decrypt`

```json
{
  "Sid": "CrossAccountDecrypt",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::999888777666:root" },
  "Action": "kms:Decrypt",
  "Resource": "*",
  "Condition": {
    "StringEquals": { "kms:ViaService": "s3.us-east-1.amazonaws.com" }
  }
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `SSEAlgorithm` | `AES256` (SSE-S3) | `aws:kms` for KMS encryption |
| `BucketKeyEnabled` | `false` | Enable S3 Bucket Key for cost savings |
| `KMSMasterKeyID` | `aws/s3` | Your customer-managed key ARN |

## See Also

- [Key Policies](../concepts/key-policies.md) -- ViaService conditions for S3
- [Envelope Encryption](../concepts/envelope-encryption.md) -- S3 uses envelope encryption internally
- [IAM KB](../../iam/) -- S3 + KMS permission policies
