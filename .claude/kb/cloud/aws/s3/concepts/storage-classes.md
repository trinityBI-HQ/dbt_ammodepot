# Storage Classes

> **Purpose**: S3 storage tiers for cost optimization based on access patterns
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 offers 8 storage classes designed for different access patterns and cost requirements. All classes provide 99.999999999% (11 nines) durability. Choosing the right class can reduce storage costs by up to 95% compared to S3 Standard.

## Storage Class Comparison

| Class | Availability | Min Storage | Retrieval Fee | Best For |
|-------|-------------|-------------|---------------|----------|
| **Standard** | 99.99% | None | None | Frequently accessed data |
| **Intelligent-Tiering** | 99.9% | None | None (auto) | Unknown/changing access patterns |
| **Standard-IA** | 99.9% | 30 days | Per-GB fee | Infrequent but fast access |
| **One Zone-IA** | 99.5% | 30 days | Per-GB fee | Reproducible infrequent data |
| **Glacier Instant** | 99.9% | 90 days | Per-GB fee | Archive, millisecond access |
| **Glacier Flexible** | 99.99% | 90 days | Per-GB + request | Archive, minutes to hours |
| **Glacier Deep Archive** | 99.99% | 180 days | Per-GB + request | Long-term compliance archive |
| **Express One Zone** | 99.95% | 1 hour | None | Single-digit ms latency (major price cuts Apr 2025) |

## Intelligent-Tiering Deep Dive

Intelligent-Tiering automatically moves objects between tiers with no retrieval fees:

| Tier | Access Pattern | Savings vs Standard |
|------|---------------|-------------------|
| Frequent Access | Default tier | 0% |
| Infrequent Access | Not accessed for 30 days | ~40% |
| Archive Instant | Not accessed for 90 days | ~68% |
| Archive Access | Not accessed for 90+ days (opt-in) | ~71% |
| Deep Archive | Not accessed for 180+ days (opt-in) | ~95% |

## S3 Express One Zone (Apr 2025 Price Cuts)

Directory buckets with single-digit millisecond latency. Major price reductions effective April 2025:

| Metric | Reduction | Impact |
|--------|-----------|--------|
| Storage cost | -31% | More affordable for large datasets |
| PUT/POST requests | -55% | Write-heavy workloads benefit |
| GET/HEAD requests | -85% | Read-intensive analytics much cheaper |

Key features: single-digit ms latency, `RenameObject` API (Jun 2025) for atomic renames up to 1 TB in milliseconds, and dedicated directory bucket type with AZ-level placement.

## The Pattern

```python
import boto3

s3 = boto3.client("s3")

# Upload with specific storage class
s3.put_object(
    Bucket="my-bucket",
    Key="archive/old-report.pdf",
    Body=open("report.pdf", "rb"),
    StorageClass="GLACIER_IR",  # Glacier Instant Retrieval
)

# Change storage class (copy object to itself)
s3.copy_object(
    Bucket="my-bucket",
    Key="data/file.csv",
    CopySource={"Bucket": "my-bucket", "Key": "data/file.csv"},
    StorageClass="STANDARD_IA",
    MetadataDirective="COPY",
)
```

```bash
# AWS CLI: Upload with storage class
aws s3 cp large-file.zip s3://my-bucket/archive/ --storage-class GLACIER

# AWS CLI: Check storage class
aws s3api head-object --bucket my-bucket --key archive/large-file.zip \
  --query StorageClass
```

## Lifecycle Transitions

```json
{
  "Rules": [{
    "ID": "OptimizeCosts",
    "Status": "Enabled",
    "Transitions": [
      { "Days": 30, "StorageClass": "STANDARD_IA" },
      { "Days": 90, "StorageClass": "GLACIER_IR" },
      { "Days": 365, "StorageClass": "DEEP_ARCHIVE" }
    ]
  }]
}
```

## Common Mistakes

### Wrong

```python
# Using Standard for rarely accessed compliance data (overpaying)
s3.put_object(Bucket="compliance", Key="audit.pdf", Body=data)
```

### Correct

```python
# Use Intelligent-Tiering for automatic cost optimization
s3.put_object(
    Bucket="compliance",
    Key="audit.pdf",
    Body=data,
    StorageClass="INTELLIGENT_TIERING",
)
```

## Related

- [versioning-lifecycle](versioning-lifecycle.md)
- [buckets-objects](buckets-objects.md)
- [../patterns/data-lake-pattern](../patterns/data-lake-pattern.md)
