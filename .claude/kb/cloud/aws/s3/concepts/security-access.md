# Security and Access Control

> **Purpose**: IAM policies, bucket policies, ACLs, encryption, and S3 security best practices
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 security operates at multiple layers: IAM policies (identity-based), bucket policies (resource-based), Block Public Access (account/bucket-level guard), and encryption (data protection). Modern best practice is to disable ACLs entirely and use IAM + bucket policies.

## Access Control Methods

| Method | Scope | Attach To | Use Case |
|--------|-------|-----------|----------|
| IAM Policy | Identity-based | Users, roles, groups | "What can this user do?" |
| Bucket Policy | Resource-based | S3 bucket | "Who can access this bucket?" |
| Block Public Access | Guard rail | Account or bucket | Prevent accidental public access |
| Access Points | Simplified access | Shared datasets | Per-application access policies |
| ACLs (legacy) | Object/bucket | Individual objects | Avoid; use policies instead |

## Bucket Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceHTTPS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    },
    {
      "Sid": "AllowCrossAccountRead",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:root" },
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

## IAM Policy for S3 Access

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::my-bucket",
      "arn:aws:s3:::my-bucket/data/*"
    ]
  }]
}
```

## Encryption Options

| Type | Key Management | Cost | Use Case |
|------|---------------|------|----------|
| SSE-S3 | AWS-managed (default) | Free | General purpose |
| SSE-KMS | AWS KMS keys | KMS API costs | Audit trail, key rotation |
| SSE-C | Customer-provided | Free (you manage) | Full key control |
| Client-side | Application-managed | None | End-to-end encryption |

## Terraform Security Configuration

```hcl
resource "aws_s3_bucket" "secure" {
  bucket = "my-secure-bucket"
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket                  = aws_s3_bucket.secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}
```

## Conditional Writes (Optimistic Concurrency)

S3 supports conditional operations to prevent race conditions (expanded Oct 2025):

| Header | Operations | Purpose |
|--------|-----------|---------|
| `If-None-Match: *` | PutObject | Write only if key doesn't exist |
| `If-Match: "etag"` | PutObject, CopyObject | Write only if ETag matches (Oct 2025) |

The `if-match` support on `CopyObject` (Oct 2025) enables safe copy-based workflows like storage class transitions and cross-account copies with optimistic concurrency control.

## Security Checklist

- Enable Block Public Access on account level
- Disable ACLs (bucket owner enforced)
- Enforce HTTPS via bucket policy condition
- Enable SSE-S3 (default) or SSE-KMS for compliance
- Enable server access logging or CloudTrail data events
- Use IAM Access Analyzer to audit policies
- Enable MFA Delete for critical buckets
- Use VPC endpoints for private network access

## Related

- [buckets-objects](buckets-objects.md)
- [versioning-lifecycle](versioning-lifecycle.md)
- [../patterns/cross-region-replication](../patterns/cross-region-replication.md)
