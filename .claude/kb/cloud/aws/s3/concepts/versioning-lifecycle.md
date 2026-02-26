# Versioning and Lifecycle

> **Purpose**: Object versioning for data protection and lifecycle rules for cost optimization
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 versioning keeps multiple variants of an object in the same bucket, protecting against accidental deletions and overwrites. Lifecycle rules automate transitions between storage classes and expiration of old objects, enabling cost optimization without manual intervention.

## Versioning States

| State | Behavior | Notes |
|-------|----------|-------|
| Unversioned | Default; no version history | Cannot be returned to after enabling |
| Enabled | All object versions preserved | Required for replication |
| Suspended | Stops creating new versions | Existing versions retained |

## The Pattern

```python
import boto3

s3 = boto3.client("s3")

# Enable versioning
s3.put_bucket_versioning(
    Bucket="my-bucket",
    VersioningConfiguration={"Status": "Enabled"},
)

# List object versions
versions = s3.list_object_versions(Bucket="my-bucket", Prefix="data/")
for version in versions.get("Versions", []):
    print(f"{version['Key']} v{version['VersionId']} "
          f"({'Latest' if version['IsLatest'] else 'Old'})")

# Restore a previous version (copy old version as current)
s3.copy_object(
    Bucket="my-bucket",
    Key="data/report.csv",
    CopySource={
        "Bucket": "my-bucket",
        "Key": "data/report.csv",
        "VersionId": "abc123",
    },
)

# Delete markers (soft delete with versioning enabled)
s3.delete_object(Bucket="my-bucket", Key="data/report.csv")
# Object is not deleted; a delete marker is placed

# Permanently delete a specific version
s3.delete_object(
    Bucket="my-bucket",
    Key="data/report.csv",
    VersionId="abc123",
)
```

## Lifecycle Rules

```json
{
  "Rules": [
    {
      "ID": "TransitionAndExpire",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER_IR" },
        { "Days": 365, "StorageClass": "DEEP_ARCHIVE" }
      ],
      "Expiration": { "Days": 2555 }
    },
    {
      "ID": "CleanupOldVersions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionTransitions": [
        { "NoncurrentDays": 30, "StorageClass": "STANDARD_IA" }
      ],
      "NoncurrentVersionExpiration": { "NoncurrentDays": 90 }
    },
    {
      "ID": "AbortIncompleteUploads",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }
  ]
}
```

## Terraform Lifecycle Configuration

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"
    filter { prefix = "data/" }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

## Common Mistakes

- Forgetting `AbortIncompleteMultipartUpload` lifecycle rule (stale uploads cost money)
- Not cleaning up noncurrent versions (storage bloat with versioning enabled)
- Transitioning to Glacier without considering minimum storage duration charges
- Suspending versioning instead of using lifecycle expiration for old versions

## Related

- [storage-classes](storage-classes.md)
- [security-access](security-access.md)
- [../patterns/cross-region-replication](../patterns/cross-region-replication.md)
