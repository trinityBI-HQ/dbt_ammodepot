# Storage Options

> **Purpose**: EMRFS, S3, HDFS, EBS volumes, and instance store for EMR clusters
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

EMR supports multiple storage layers. EMRFS (S3-backed) is the primary storage for data lake workloads, replacing HDFS for most use cases. HDFS remains relevant for intermediate shuffle data and low-latency local storage. EBS volumes and instance store provide local disk for HDFS, shuffle, and temporary data.

## Storage Comparison

| Storage | Persistence | Performance | Cost | Use Case |
|---------|------------|-------------|------|----------|
| **EMRFS (S3)** | Durable | High throughput | Low (pay per use) | Primary data store |
| **HDFS** | Cluster lifetime | Low latency | Included (instance disk) | Shuffle, temp data |
| **EBS** | Cluster lifetime | Moderate | Pay per volume | Additional HDFS capacity |
| **Instance Store** | Instance lifetime | Highest IOPS | Included | Scratch, shuffle, cache |

## EMRFS (S3 as Filesystem)

EMRFS implements the Hadoop filesystem interface on top of S3:

```python
# Read from S3 via EMRFS -- transparent to Spark
df = spark.read.parquet("s3://data-lake/silver/orders/")

# Write to S3 via EMRFS
df.write.mode("overwrite") \
    .partitionBy("year", "month") \
    .parquet("s3://data-lake/gold/orders/")
```

### EMRFS Features

| Feature | Description |
|---------|-------------|
| **S3A Connector** | Default since EMR 7.x, improved performance |
| **EMRFS Consistent View** | DynamoDB-backed consistency (legacy, S3 now strongly consistent) |
| **S3 Select** | Push predicate filtering to S3 for CSV/JSON |
| **Encryption** | SSE-S3, SSE-KMS, CSE-KMS, CSE-Custom |

**Important**: S3 now provides strong read-after-write consistency natively. EMRFS Consistent View (DynamoDB) is no longer needed for new clusters.

### EMRFS vs S3A URI Schemes

| URI | Implementation | Notes |
|-----|---------------|-------|
| `s3://` | EMRFS | EMR-optimized, recommended |
| `s3a://` | Hadoop S3A | Standard Hadoop, works on EMR 7.x |
| `s3n://` | Deprecated | Do not use |

## HDFS on EMR

HDFS runs on core node local disks and attached EBS volumes:

```
Core Node
├── Instance Store (/mnt/)  → HDFS DataNode
├── EBS Volume (/mnt1/)     → HDFS DataNode (additional)
└── Root Volume              → OS, logs
```

### When to Use HDFS

- Iterative algorithms requiring fast re-reads (ML training)
- Intermediate shuffle data for large Spark jobs
- HBase table storage (requires HDFS)
- Jobs with many small files (HDFS is faster than S3 for small file I/O)

### HDFS Replication

| Setting | Default | Impact |
|---------|---------|--------|
| `dfs.replication` | 3 (if 10+ nodes), 2 (4-9), 1 (1-3) | Higher = more durability, more disk |

## EBS Volumes

EBS volumes attach to cluster nodes for additional storage:

```json
{
  "InstanceGroups": [{
    "InstanceType": "m5.xlarge",
    "EbsConfiguration": {
      "EbsBlockDeviceConfigs": [{
        "VolumeSpecification": {
          "VolumeType": "gp3",
          "SizeInGB": 500,
          "Iops": 3000,
          "Throughput": 125
        },
        "VolumesPerInstance": 2
      }]
    }
  }]
}
```

| Volume Type | IOPS | Throughput | Use Case |
|------------|------|------------|----------|
| gp3 | 3,000-16,000 | 125-1,000 MB/s | General purpose |
| io2 | Up to 64,000 | Up to 1,000 MB/s | High IOPS shuffle |
| st1 | 500 baseline | 500 MB/s | Sequential reads |

**Warning**: EBS volumes on EMR are **ephemeral** -- deleted when the cluster or instance terminates.

## Instance Store

NVMe SSDs physically attached to the host (e.g., i3, d3, r5d):

- Highest IOPS and lowest latency
- Ideal for shuffle-heavy Spark workloads
- Lost if instance stops/terminates
- Not available on all instance types

## Storage Decision Matrix

| Workload | Primary Storage | Local Storage |
|----------|----------------|---------------|
| Data lake ETL (most common) | S3 (EMRFS) | Default EBS |
| Shuffle-heavy Spark jobs | S3 (EMRFS) | Instance store (i3/d3) |
| HBase | S3 (via S3 storage mode) + HDFS | EBS gp3 |
| ML training (iterative reads) | HDFS or S3 with caching | Instance store |
| Streaming (Kafka/Kinesis) | S3 (EMRFS) for output | EBS for checkpoints |

## Common Mistakes

### Wrong

```python
# Storing final output on HDFS -- lost when cluster terminates
df.write.parquet("hdfs:///output/final/")
```

### Correct

```python
# Always write final output to S3 for persistence
df.write.parquet("s3://data-lake/output/final/")
# Use HDFS only for intermediate/temp data
```

## Related

- [Cluster Architecture](cluster-architecture.md) -- Node types and storage
- [Spark on EMR](spark-on-emr.md) -- Spark I/O optimization
- [AWS S3 KB](../../s3/) -- S3 storage fundamentals
