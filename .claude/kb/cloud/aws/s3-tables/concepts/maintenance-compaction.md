# Table Maintenance and Compaction

> **Purpose**: Automatic compaction, snapshot management, and unreferenced file cleanup
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Tables automatically maintains your Iceberg tables with three operations: **compaction** (merging small files), **snapshot management** (expiring old snapshots), and **unreferenced file removal** (cleaning orphan files). All are enabled by default.

## Maintenance Operations

| Operation | Level | Default | Purpose |
|-----------|-------|---------|---------|
| Compaction | Table | Enabled, 512 MB target | Merge small files for better query performance |
| Snapshot management | Table | Enabled, min 1, max 72h | Expire old snapshots, reduce metadata overhead |
| Unreferenced file removal | Bucket | Enabled | Delete orphan data files not in any snapshot |

## Compaction

Compaction merges multiple small Parquet files into fewer, larger files. This is critical for query performance — fewer files means fewer S3 LIST/GET operations.

### Configuration

```python
import boto3

s3tables = boto3.client("s3tables")

# Configure compaction (table level)
s3tables.put_table_maintenance_configuration(
    tableBucketARN="arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket",
    namespace="sales",
    name="transactions",
    type="icebergCompaction",
    value={
        "status": "enabled",
        "settings": {
            "icebergCompaction": {
                "targetFileSizeMB": 256,  # 64-512 MB range
                "strategy": "auto",       # auto | binpack | sort | z-order
            }
        },
    },
)
```

### CLI Configuration

```bash
aws s3tables put-table-maintenance-configuration \
  --table-bucket-arn arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket \
  --namespace sales \
  --name transactions \
  --type icebergCompaction \
  --value '{"status":"enabled","settings":{"icebergCompaction":{"targetFileSizeMB":256,"strategy":"sort"}}}'
```

### Compaction Strategies (Sort/Z-Order GA Jun 2025)

| Strategy | Best For | Description |
|----------|----------|-------------|
| `auto` | Most workloads (default) | S3 selects based on table sort order |
| `binpack` | No sort order needed | Combines files by size only |
| `sort` | Range queries on sort key | Sorts data within compacted files by sort order |
| `z-order` | Multi-column filter queries | Interleaves sort on multiple columns |

Sort and z-order compaction (GA Jun 2025) can run **automated** (continuous) or **on-demand** (via API). Sort uses the table's defined sort order; z-order interleaves multiple columns for multi-predicate query optimization.

## Snapshot Management

Snapshots track the state of a table at a point in time. Old snapshots consume metadata storage and slow down operations.

```python
# Configure snapshot management
s3tables.put_table_maintenance_configuration(
    tableBucketARN="arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket",
    namespace="sales",
    name="transactions",
    type="icebergSnapshotManagement",
    value={
        "status": "enabled",
        "settings": {
            "icebergSnapshotManagement": {
                "minSnapshotsToKeep": 3,
                "maxSnapshotAgeHours": 168,  # 7 days
            }
        },
    },
)
```

When a snapshot expires, referenced data files shared with newer snapshots are retained; files only referenced by the expired snapshot are marked noncurrent.

## Unreferenced File Removal (Bucket Level)

Cleans up orphan data files not referenced by any active snapshot:

```python
# Configure at bucket level
s3tables.put_table_bucket_maintenance_configuration(
    tableBucketARN="arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket",
    type="icebergUnreferencedFileRemoval",
    value={
        "status": "enabled",
        "settings": {
            "icebergUnreferencedFileRemoval": {
                "unreferencedDays": 3,   # Days before marking noncurrent
                "nonCurrentDays": 10,    # Days before deletion
            }
        },
    },
)
```

## Monitoring Maintenance

- **CloudTrail**: Logs all automated maintenance operations
- **Get current config**: `get_table_maintenance_configuration()` / `get_table_maintenance_job_status()`

```python
# Check maintenance status
config = s3tables.get_table_maintenance_configuration(
    tableBucketARN=bucket_arn, namespace="sales", name="transactions"
)
for mtype, cfg in config["configuration"].items():
    print(f"{mtype}: {cfg['status']}")
```

## Best Practices

| Practice | Why |
|----------|-----|
| Keep compaction enabled (default) | Small files degrade query performance significantly |
| Use `auto` strategy unless you know your query patterns | S3 optimizes based on sort order |
| Retain 3-7 days of snapshots for time travel | Balance between history and metadata overhead |
| Monitor via CloudTrail | Track compaction frequency and failures |

## Common Mistakes

- Disabling compaction for cost savings (queries become slower, costs more overall)
- Setting target file size too small (< 128 MB increases file count)
- Not configuring unreferenced file removal (orphan files accumulate)

## Related

- [table-buckets-namespaces](table-buckets-namespaces.md)
- [iceberg-integration](iceberg-integration.md)
- [../patterns/data-lake-medallion](../patterns/data-lake-medallion.md)
