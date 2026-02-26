# Buckets and Objects

> **Purpose**: Core S3 data model -- buckets, objects, keys, and prefixes
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Amazon S3 stores data as objects within buckets. A bucket is a container for objects, and an object is a file plus metadata identified by a unique key. S3 uses a flat namespace but supports logical hierarchy through key prefixes delimited by `/`.

## The Pattern

```python
import boto3

s3 = boto3.client("s3")

# Create a bucket
s3.create_bucket(
    Bucket="my-data-bucket",
    CreateBucketConfiguration={"LocationConstraint": "us-west-2"},
)

# Upload an object
s3.upload_file(
    Filename="data.csv",
    Bucket="my-data-bucket",
    Key="raw/2026/02/data.csv",  # Key with prefix hierarchy
)

# Download an object
s3.download_file(
    Bucket="my-data-bucket",
    Key="raw/2026/02/data.csv",
    Filename="local-data.csv",
)

# List objects by prefix
response = s3.list_objects_v2(
    Bucket="my-data-bucket",
    Prefix="raw/2026/",
    Delimiter="/",
)
for obj in response.get("Contents", []):
    print(obj["Key"], obj["Size"])
```

## Quick Reference

| Component | Description | Limits |
|-----------|-------------|--------|
| Bucket | Top-level container | 100 per account (soft limit) |
| Object | File + metadata | Up to **50 TB** per object (Dec 2025) |
| Key | Unique identifier within bucket | Up to 1,024 bytes UTF-8 |
| Prefix | Logical folder (part of key) | No limit on depth |
| Metadata | Key-value pairs on objects | 2 KB total user metadata |
| Tags | Key-value pairs for management | 10 tags per object |

**Note**: The 50 TB max object size (increased from 5 TB in Dec 2025) requires multipart upload for objects >5 GB. Single PUT operations remain limited to 5 GB.

## Bucket Naming Rules

- 3-63 characters, lowercase letters, numbers, hyphens
- Must start with a letter or number
- Globally unique across all AWS accounts
- Cannot be formatted as an IP address

## Object Key Best Practices

| Pattern | Example | Use Case |
|---------|---------|----------|
| Date-partitioned | `logs/2026/02/12/app.log` | Time-series data |
| Hive-style | `data/year=2026/month=02/file.parquet` | Athena/Glue queries |
| Randomized prefix | `a1b2c3/data.csv` | High-throughput workloads |

## Common Mistakes

### Wrong

```python
# Listing all objects without pagination (misses objects beyond 1000)
response = s3.list_objects_v2(Bucket="my-bucket")
objects = response["Contents"]
```

### Correct

```python
# Use paginator for complete listing
paginator = s3.get_paginator("list_objects_v2")
for page in paginator.paginate(Bucket="my-bucket", Prefix="data/"):
    for obj in page.get("Contents", []):
        print(obj["Key"])
```

## S3 Express One Zone: RenameObject API (Jun 2025)

S3 Express One Zone directory buckets support atomic object renames:

```python
# Atomic rename (Express One Zone directory buckets only)
s3.rename_object(
    Bucket="my-express-bucket--use1-az1--x-s3",
    Key="staging/data.parquet",
    RenameSource="staging/data.parquet",
    DestinationKey="processed/data.parquet",
)
# Renames up to 1 TB in milliseconds — no copy+delete needed
```

## Conditional Writes

S3 supports conditional writes to prevent race conditions:

```python
# PutObject only if key doesn't exist (if-none-match)
s3.put_object(
    Bucket="my-bucket", Key="data/file.csv", Body=data,
    IfNoneMatch="*",  # Fails if object already exists
)

# CopyObject only if source ETag matches (if-match, Oct 2025)
s3.copy_object(
    Bucket="my-bucket", Key="data/copy.csv",
    CopySource={"Bucket": "my-bucket", "Key": "data/file.csv"},
    CopySourceIfMatch='"etag-value"',  # Ensures source hasn't changed
)
```

## Presigned URLs

```python
# Generate a presigned URL for temporary access (default 1 hour)
url = s3.generate_presigned_url(
    ClientMethod="get_object",
    Params={"Bucket": "my-bucket", "Key": "report.pdf"},
    ExpiresIn=3600,
)
```

## Related

- [storage-classes](storage-classes.md)
- [security-access](security-access.md)
- [../patterns/performance-optimization](../patterns/performance-optimization.md)
