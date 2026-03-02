# Spark on EMR

> **Purpose**: EMR-optimized Spark runtime, performance gains, Glue Catalog, table format support
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

Amazon EMR includes an optimized Apache Spark runtime that is fully API-compatible with open-source Spark but delivers significant performance improvements. EMR 7.12 runs TPC-DS 3TB workloads 4.5x faster than open-source Spark 3.5.6. The optimizations include metadata caching, parallel I/O, adaptive query planning, and improved fault tolerance.

## EMR Spark Runtime Optimizations

| Optimization | Description | Impact |
|-------------|-------------|--------|
| **Adaptive Query Execution** | Enhanced AQE with better statistics | 2-3x faster joins |
| **Dynamic Partition Pruning** | Prunes partitions at runtime | Fewer S3 reads |
| **EMRFS S3 Connector** | S3A-based optimized connector | Faster S3 I/O |
| **Bloom Filter Joins** | Auto-applied bloom filters | Reduced shuffle |
| **Columnar Reader** | Vectorized Parquet/ORC reading | Faster scans |
| **Metadata Caching** | Cache Glue Catalog metadata | Fewer API calls |

## Glue Data Catalog as Metastore

EMR can use AWS Glue Data Catalog as an Apache Hive-compatible metastore:

```json
[
  {
    "Classification": "spark-hive-site",
    "Properties": {
      "hive.metastore.client.factory.class":
        "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
    }
  }
]
```

Benefits:
- Shared catalog across EMR, Athena, Glue, Redshift Spectrum
- No separate Hive Metastore to manage
- Automatic schema registration from crawlers
- Lake Formation fine-grained access control

```python
# PySpark reading from Glue Catalog table
spark = SparkSession.builder \
    .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.glue_catalog.warehouse", "s3://warehouse/") \
    .config("spark.sql.catalog.glue_catalog.catalog-impl",
            "org.apache.iceberg.aws.glue.GlueCatalog") \
    .getOrCreate()

df = spark.read.table("glue_catalog.analytics.orders")
```

## Table Format Support (EMR 7.12)

| Format | Version | Key Features |
|--------|---------|-------------|
| **Apache Iceberg** | 1.10.0 | Format v3, deletion vectors, row lineage |
| **Apache Hudi** | 1.0.2 | Record-level indexing, MOR tables |
| **Delta Lake** | 3.3.2 | Deletion vectors, liquid clustering |

### Iceberg on EMR

```python
# Create Iceberg table via Spark
spark.sql("""
    CREATE TABLE glue_catalog.silver.events (
        event_id STRING,
        event_ts TIMESTAMP,
        user_id BIGINT,
        payload STRING
    )
    USING iceberg
    PARTITIONED BY (days(event_ts))
    TBLPROPERTIES ('format-version' = '3')
""")

# MERGE (upsert) with Iceberg
spark.sql("""
    MERGE INTO glue_catalog.silver.events t
    USING staging_events s ON t.event_id = s.event_id
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
```

### Iceberg v3 Features (EMR 7.12+)

- **Deletion vectors**: Mark deleted rows without rewriting files
- **Row-level lineage**: Track row provenance across transforms
- **Nanosecond timestamps**: Higher precision temporal data

## Spark Configuration Best Practices

```json
[
  {
    "Classification": "spark-defaults",
    "Properties": {
      "spark.dynamicAllocation.enabled": "true",
      "spark.dynamicAllocation.minExecutors": "2",
      "spark.dynamicAllocation.maxExecutors": "100",
      "spark.sql.adaptive.enabled": "true",
      "spark.sql.adaptive.coalescePartitions.enabled": "true",
      "spark.serializer": "org.apache.spark.serializer.KryoSerializer",
      "spark.sql.iceberg.handle-timestamp-without-timezone": "true"
    }
  }
]
```

## Common Mistakes

### Wrong

```python
# Not using Glue Catalog -- loses cross-service catalog sharing
spark = SparkSession.builder \
    .config("spark.sql.catalogImplementation", "in-memory") \
    .getOrCreate()
```

### Correct

```python
# Use Glue Catalog for unified metadata
spark = SparkSession.builder \
    .config("spark.sql.catalogImplementation", "hive") \
    .enableHiveSupport() \
    .getOrCreate()
# Glue Catalog enabled via EMR cluster configuration
```

## Related

- [Cluster Architecture](cluster-architecture.md) -- Node sizing for Spark
- [Storage Options](storage-options.md) -- S3 vs HDFS for Spark
- [Spark Submit Patterns](../patterns/spark-submit-patterns.md) -- Running Spark jobs
