# Table Buckets, Namespaces, and Tables

> **Purpose**: Core S3 Tables data model — table buckets, namespaces, tables, and ARNs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Tables introduces a new bucket type — **table buckets** — purpose-built for storing Apache Iceberg tables. Tables are organized into namespaces within a table bucket, forming a three-level hierarchy: `table-bucket → namespace → table`.

## Hierarchy

```
AWS Account / Region
  └── Table Bucket (dedicated bucket type)
       └── Namespace (logical grouping, maps to Glue database)
            └── Table (Apache Iceberg format, subresource of bucket)
```

## Resource Limits

| Resource | Default Limit | Notes |
|----------|--------------|-------|
| Table buckets per region | 10 | Soft limit, request increase |
| Tables per table bucket | 10,000 | Soft limit |
| Namespaces per table bucket | No documented limit | Organize logically |

## ARN Formats

```
Table bucket: arn:aws:s3tables:{region}:{account-id}:bucket/{bucket-name}
Table:        arn:aws:s3tables:{region}:{account-id}:bucket/{bucket-name}/table/{table-id}
```

## Creating Resources with AWS CLI

```bash
# Create a table bucket
aws s3tables create-table-bucket \
  --region us-east-1 \
  --name my-analytics-bucket

# Create a namespace
aws s3tables create-namespace \
  --table-bucket-arn arn:aws:s3tables:us-east-1:123456789012:bucket/my-analytics-bucket \
  --namespace sales

# Create a table
aws s3tables create-table \
  --table-bucket-arn arn:aws:s3tables:us-east-1:123456789012:bucket/my-analytics-bucket \
  --namespace sales \
  --name transactions \
  --format ICEBERG
```

## Creating Resources with boto3

```python
import boto3

s3tables = boto3.client("s3tables")

# Create table bucket
response = s3tables.create_table_bucket(name="my-analytics-bucket")
bucket_arn = response["arn"]

# Create namespace
s3tables.create_namespace(tableBucketARN=bucket_arn, namespace=["sales"])

# Create table (minimal — schema can be added via query engine)
response = s3tables.create_table(
    tableBucketARN=bucket_arn,
    namespace="sales",
    name="transactions",
    format="ICEBERG",
)
table_arn = response["tableARN"]

# Create table with schema
response = s3tables.create_table(
    tableBucketARN=bucket_arn,
    namespace="sales",
    name="orders",
    format="ICEBERG",
    metadata={
        "iceberg": {
            "schema": {
                "fields": [
                    {"name": "order_id", "type": "long", "required": True},
                    {"name": "customer_id", "type": "long", "required": True},
                    {"name": "amount", "type": "decimal(10,2)", "required": False},
                    {"name": "order_date", "type": "date", "required": True},
                ]
            }
        }
    },
)
```

## Listing and Inspecting Resources

```python
# List table buckets
buckets = s3tables.list_table_buckets()
for b in buckets["tableBuckets"]:
    print(f"{b['name']} - {b['arn']}")

# List namespaces
namespaces = s3tables.list_namespaces(tableBucketARN=bucket_arn)

# List tables in a namespace
tables = s3tables.list_tables(tableBucketARN=bucket_arn, namespace="sales")

# Get table metadata location (for Iceberg catalog)
meta = s3tables.get_table_metadata_location(
    tableBucketARN=bucket_arn, namespace="sales", name="transactions"
)
print(f"Metadata: {meta['metadataLocation']}")
```

## Table Bucket Naming Rules

- 3-63 characters, lowercase letters, numbers, hyphens
- Unique within your account per region (not globally unique like S3 buckets)
- Cannot be renamed after creation

## Table vs General Purpose Buckets

| Feature | Table Bucket | General Purpose Bucket |
|---------|-------------|----------------------|
| Purpose | Tabular data (Iceberg) | Any object storage |
| Namespace | `s3tables:*` IAM actions | `s3:*` IAM actions |
| Maintenance | Built-in compaction/snapshots | None |
| Query throughput | Up to 3x faster | Baseline |
| Direct object access | Via Iceberg APIs only | Direct GET/PUT |

## Related

- [iceberg-integration](iceberg-integration.md)
- [maintenance-compaction](maintenance-compaction.md)
- [../patterns/terraform-setup](../patterns/terraform-setup.md)
