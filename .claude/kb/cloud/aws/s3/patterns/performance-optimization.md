# S3 Performance Optimization

> **Purpose**: Maximize throughput with multipart upload, transfer acceleration, and prefix design
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 supports 3,500 PUT/POST/DELETE and 5,500 GET/HEAD requests per second **per prefix**. Performance scales linearly with prefixes. Key optimizations: multipart uploads for large files, transfer acceleration for long-distance transfers, and parallel prefix design for high-throughput workloads.

## Request Rate Scaling

| Strategy | Throughput |
|----------|-----------|
| Single prefix | 5,500 GET/s, 3,500 PUT/s |
| 10 prefixes | 55,000 GET/s, 35,000 PUT/s |
| 100 prefixes | 550,000 GET/s, 350,000 PUT/s |

S3 automatically partitions prefixes under load — no manual action needed.

## Multipart Upload

Use multipart for files > 100 MB. Breaks files into parts uploaded in parallel. **Required for objects >5 GB** and supports the new 50 TB max object size (Dec 2025) with up to 10,000 parts of 5 GB each.

### boto3 with TransferConfig

```python
import boto3
from boto3.s3.transfer import TransferConfig

s3 = boto3.client("s3")

config = TransferConfig(
    multipart_threshold=100 * 1024 * 1024,  # 100 MB
    multipart_chunksize=25 * 1024 * 1024,   # 25 MB per part
    max_concurrency=10,                       # 10 parallel threads
    use_threads=True,
)

# Upload automatically uses multipart when file exceeds threshold
s3.upload_file(
    "large-dataset.parquet",
    "my-bucket",
    "data/large-dataset.parquet",
    Config=config,
)
```

### Manual Multipart (Advanced)

```python
# For custom control over individual parts
mpu = s3.create_multipart_upload(Bucket="my-bucket", Key="data/huge-file.tar.gz")
upload_id = mpu["UploadId"]

parts = []
part_number = 1
with open("huge-file.tar.gz", "rb") as f:
    while chunk := f.read(25 * 1024 * 1024):  # 25 MB chunks
        response = s3.upload_part(
            Bucket="my-bucket",
            Key="data/huge-file.tar.gz",
            PartNumber=part_number,
            UploadId=upload_id,
            Body=chunk,
        )
        parts.append({"PartNumber": part_number, "ETag": response["ETag"]})
        part_number += 1

s3.complete_multipart_upload(
    Bucket="my-bucket",
    Key="data/huge-file.tar.gz",
    UploadId=upload_id,
    MultipartUpload={"Parts": parts},
)
```

## Transfer Acceleration

Uses CloudFront edge locations to optimize routing for long-distance transfers.

### Enable on Bucket

```python
s3.put_bucket_accelerate_configuration(
    Bucket="my-bucket",
    AccelerateConfiguration={"Status": "Enabled"},
)
```

### Use Accelerated Endpoint

```python
from botocore.config import Config

s3_accel = boto3.client(
    "s3",
    config=Config(s3={"use_accelerate_endpoint": True}),
)

s3_accel.upload_file("large-file.tar.gz", "my-bucket", "uploads/large-file.tar.gz")
```

### Terraform

```hcl
resource "aws_s3_bucket_accelerate_configuration" "accel" {
  bucket = aws_s3_bucket.uploads.id
  status = "Enabled"
}
```

### When to Use Transfer Acceleration

| Scenario | Use Acceleration? |
|----------|-------------------|
| Same-region EC2 → S3 | No (negligible benefit) |
| Cross-continent client → S3 | Yes |
| Users uploading from global locations | Yes |
| Small files (<1 MB) | No (overhead outweighs benefit) |

## Byte-Range Fetches

Download specific byte ranges for parallelism or partial reads:

```python
# Download only first 1 MB of a large file
response = s3.get_object(
    Bucket="my-bucket",
    Key="data/large-file.parquet",
    Range="bytes=0-1048575",
)
header_bytes = response["Body"].read()
```

Use cases: reading Parquet footers, parallel downloads, resumable transfers.

## Prefix Design for High Throughput

### Good: Hive-Style Partitioning

```
data/year=2026/month=02/day=12/file_001.parquet
data/year=2026/month=02/day=12/file_002.parquet
```

### Good: Hash-Based Distribution

```python
import hashlib

def distributed_key(filename: str, prefix: str = "data") -> str:
    hash_prefix = hashlib.md5(filename.encode()).hexdigest()[:4]
    return f"{prefix}/{hash_prefix}/{filename}"

# Produces: data/a1b2/invoice_001.pdf
```

### Bad: Sequential Keys

```
data/000001.csv   # All land on same partition
data/000002.csv
data/000003.csv
```

## Parallel Downloads

Use `concurrent.futures.ThreadPoolExecutor(max_workers=10)` to download multiple objects in parallel. Each thread calls `s3.download_file()` independently.

## Decision Matrix

| File Size | Distance | Strategy |
|-----------|----------|----------|
| < 100 MB | Same region | Standard `upload_file` |
| > 100 MB | Same region | Multipart with concurrency |
| > 5 TB | Any | Multipart (required), up to 50 TB max |
| < 100 MB | Cross-region | Standard (consider acceleration) |
| > 100 MB | Cross-region | Multipart + Transfer Acceleration |
| Many small files | Any | Thread pool with `max_workers=20` |
| Large reads | Any | Byte-range fetches in parallel |

## AWS CLI Performance Flags

```bash
# Increase concurrency for sync/cp
aws configure set default.s3.max_concurrent_requests 20
aws configure set default.s3.multipart_chunksize 25MB
aws configure set default.s3.max_bandwidth 50MB/s

# Use transfer acceleration
aws s3 cp large-file.tar.gz s3://my-bucket/ --endpoint-url https://my-bucket.s3-accelerate.amazonaws.com
```

## Related

- [../concepts/buckets-objects](../concepts/buckets-objects.md)
- [../concepts/storage-classes](../concepts/storage-classes.md)
- [data-lake-pattern](data-lake-pattern.md)
