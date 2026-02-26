# Cross-Region Replication (CRR/SRR)

> **Purpose**: Replicate objects between S3 buckets for DR, compliance, and latency optimization
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Replication automatically copies objects between buckets. **Cross-Region Replication (CRR)** copies across AWS regions; **Same-Region Replication (SRR)** copies within the same region. Both require versioning enabled on source and destination.

## When to Use

| Scenario | Type | Why |
|----------|------|-----|
| Disaster recovery | CRR | Data survives regional outage |
| Compliance (data sovereignty) | CRR | Copy to required jurisdictions |
| Reduce latency for global users | CRR | Serve from nearest region |
| Log aggregation | SRR | Consolidate logs from multiple buckets |
| Cross-account data sharing | SRR/CRR | Replicate to partner accounts |
| Replication with SLA | S3 RTC | 99.99% of objects within 15 minutes |

## Prerequisites

1. Versioning enabled on **both** source and destination buckets
2. IAM role with `s3:ReplicateObject`, `s3:ReplicateDelete` permissions
3. Destination bucket must allow the replication role

## Terraform Implementation

### Buckets with Versioning

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "source" {
  provider = aws.primary
  bucket   = "my-data-source-bucket"
}

resource "aws_s3_bucket_versioning" "source" {
  provider = aws.primary
  bucket   = aws_s3_bucket.source.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket" "destination" {
  provider = aws.replica
  bucket   = "my-data-replica-bucket"
}

resource "aws_s3_bucket_versioning" "destination" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination.id
  versioning_configuration { status = "Enabled" }
}
```

### IAM Role for Replication

```hcl
resource "aws_iam_role" "replication" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.source.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl",
                     "s3:GetObjectVersionTagging"]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "${aws_s3_bucket.destination.arn}/*"
      },
    ]
  })
}
```

### Replication Configuration

```hcl
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.source]
  role       = aws_iam_role.replication.arn
  bucket     = aws_s3_bucket.source.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}  # Empty filter = replicate all objects

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD_IA"  # Save costs on replica
    }

    delete_marker_replication { status = "Enabled" }
  }
}
```

### Selective Replication (by Prefix/Tag)

```hcl
rule {
  id     = "replicate-critical-only"
  status = "Enabled"

  filter {
    and {
      prefix = "critical/"
      tags   = { replicate = "true" }
    }
  }

  destination {
    bucket        = aws_s3_bucket.destination.arn
    storage_class = "STANDARD"
  }
}
```

## boto3: Check Replication Status

```python
import boto3

s3 = boto3.client("s3")

response = s3.head_object(Bucket="my-data-source-bucket", Key="critical/data.parquet")
status = response.get("ReplicationStatus")  # COMPLETE, PENDING, FAILED, REPLICA
print(f"Replication status: {status}")
```

## Replication Time Control (RTC)

For SLA-backed replication (99.99% within 15 minutes), add `replication_time` and `metrics` blocks to the destination with `status = "Enabled"` and `time { minutes = 15 }`.

## Key Limitations

| Limitation | Details |
|-----------|---------|
| Existing objects | Not replicated — use S3 Batch Replication |
| Chaining | Replica of replica not supported |
| Versioning | Must be enabled on both buckets |
| Delete markers | Optional; permanent deletes never replicated |
| SSE-C objects | Not replicated |
| Lifecycle actions | Not replicated (configure on each bucket) |

## Monitoring

- **S3 Replication Metrics** in CloudWatch: `ReplicationLatency`, `OperationsPendingReplication`
- **S3 Inventory** reports: compare source vs destination object counts
- **EventBridge**: trigger alerts on replication failures

## Related

- [../concepts/versioning-lifecycle](../concepts/versioning-lifecycle.md)
- [../concepts/security-access](../concepts/security-access.md)
- [Terraform KB](../../../../devops-sre/iac/terraform/)
