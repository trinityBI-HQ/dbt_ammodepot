# AWS S3 Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Core CLI Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `aws s3 cp` | Copy file to/from S3 | `aws s3 cp file.csv s3://bucket/key` |
| `aws s3 sync` | Sync directory | `aws s3 sync ./data s3://bucket/data/` |
| `aws s3 ls` | List objects | `aws s3 ls s3://bucket/prefix/` |
| `aws s3 rm` | Delete object | `aws s3 rm s3://bucket/key --recursive` |
| `aws s3 mb` | Create bucket | `aws s3 mb s3://my-bucket --region us-east-1` |
| `aws s3 presign` | Generate presigned URL | `aws s3 presign s3://bucket/key --expires-in 3600` |
| `aws s3api put-bucket-versioning` | Enable versioning | `--versioning-configuration Status=Enabled` |

## Core boto3 Operations

| Operation | Method | Key Args |
|-----------|--------|----------|
| Upload file | `s3.upload_file()` | `Filename, Bucket, Key` |
| Download file | `s3.download_file()` | `Bucket, Key, Filename` |
| List objects | `s3.list_objects_v2()` | `Bucket, Prefix` |
| Delete object | `s3.delete_object()` | `Bucket, Key` |
| Presigned URL | `s3.generate_presigned_url()` | `ClientMethod, Params, ExpiresIn` |
| Put object | `s3.put_object()` | `Bucket, Key, Body` |

## Storage Classes at a Glance

| Class | Access | Min Duration | Retrieval | Use Case |
|-------|--------|-------------|-----------|----------|
| Standard | Frequent | None | Instant | Active data |
| Intelligent-Tiering | Any | None | Instant | Unknown patterns |
| Standard-IA | Infrequent | 30 days | Instant | Backups |
| One Zone-IA | Infrequent | 30 days | Instant | Reproducible data |
| Glacier Instant | Rare | 90 days | Milliseconds | Archives, instant access |
| Glacier Flexible | Rare | 90 days | 1-12 hours | Long-term archive |
| Glacier Deep Archive | Very rare | 180 days | 12-48 hours | Compliance archive |

## Key Limits (Updated Dec 2025)

| Limit | Value | Notes |
|-------|-------|-------|
| Max object size | **50 TB** | Up from 5 TB (Dec 2025); multipart required >5 TB |
| Max single PUT | 5 GB | Use multipart upload for larger objects |
| Max part size | 5 GB | Multipart upload part limit |
| Max parts per upload | 10,000 | Enables 50 TB objects (10,000 x 5 GB) |
| Bucket name | Globally unique | 3-63 chars, lowercase |

## Recent Features (2025)

| Feature | Date | Details |
|---------|------|---------|
| 50 TB max object size | Dec 2025 | 10x increase, multipart required >5 TB |
| S3 Metadata | Dec 2025 | Available in 22 regions |
| Conditional writes on CopyObject | Oct 2025 | `if-match` (ETag) support |
| Express One Zone: RenameObject | Jun 2025 | Atomic rename, 1 TB in milliseconds |
| Express One Zone: price cuts | Apr 2025 | Storage -31%, PUT -55%, GET -85% |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Active app data | S3 Standard |
| Unknown access patterns | Intelligent-Tiering |
| Backups accessed monthly | Standard-IA |
| Data lake raw zone | Standard + lifecycle to IA |
| Compliance archives (7+ years) | Glacier Deep Archive |
| Static website | Standard + CloudFront |
| Cross-region DR | CRR with versioning |
| Large file uploads (>100MB) | Multipart upload |
| Ultra-low latency (<10ms) | S3 Express One Zone |

## Security Checklist

| Setting | Recommendation |
|---------|---------------|
| Block Public Access | Enable on all accounts and buckets |
| Encryption | SSE-S3 (default) or SSE-KMS for compliance |
| ACLs | Disable; use bucket policies + IAM instead |
| HTTPS | Enforce via `aws:SecureTransport` condition |
| Versioning | Enable for critical data |
| Access logging | Enable server access logging |
| MFA Delete | Enable for production buckets |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use ACLs for access control | Use bucket policies + IAM policies |
| Make buckets public without review | Enable Block Public Access by default |
| Upload large files in single PUT | Use multipart upload for files >100MB |
| Use sequential key names for high throughput | Use randomized prefixes for parallelism |
| Skip encryption configuration | Rely on default SSE-S3 or configure SSE-KMS |
| Forget lifecycle rules | Set transitions to save on storage costs |

See `index.md` for full navigation and `concepts/buckets-objects.md` to get started.
