# Medallion Architecture with S3 Tables

> **Purpose**: Bronze/Silver/Gold data lake pattern using managed S3 Tables
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Tables simplifies the medallion architecture by providing managed Iceberg tables with automatic compaction and snapshot management. Instead of managing raw Parquet files on S3, each layer is a proper Iceberg table with ACID transactions.

## Architecture

```
Sources → Bronze (raw Iceberg tables) → Silver (cleaned) → Gold (aggregated)
          [auto-compaction]              [auto-compaction]   [auto-compaction]
```

All layers share one table bucket with separate namespaces:

```
Table Bucket: analytics-lakehouse
├── Namespace: bronze
│   ├── raw_orders
│   ├── raw_customers
│   └── raw_events
├── Namespace: silver
│   ├── orders
│   ├── customers
│   └── events
└── Namespace: gold
    ├── daily_revenue
    ├── customer_lifetime_value
    └── product_performance
```

## Setup

```python
import boto3

s3tables = boto3.client("s3tables")

# Create table bucket
response = s3tables.create_table_bucket(name="analytics-lakehouse")
bucket_arn = response["arn"]

# Create namespaces for each layer
for ns in ["bronze", "silver", "gold"]:
    s3tables.create_namespace(tableBucketARN=bucket_arn, namespace=[ns])
```

## Bronze Layer: Raw Ingestion

```sql
-- Create Bronze table via Athena
CREATE TABLE "s3tablescatalog/analytics-lakehouse".bronze.raw_orders (
    order_id BIGINT,
    customer_id BIGINT,
    product_id BIGINT,
    amount STRING,          -- Keep as STRING (raw, no type coercion)
    order_date STRING,
    source_system STRING,
    ingested_at TIMESTAMP
)
TBLPROPERTIES ('table_type' = 'ICEBERG');

-- Ingest raw data
INSERT INTO "s3tablescatalog/analytics-lakehouse".bronze.raw_orders
SELECT *, 'erp' as source_system, current_timestamp as ingested_at
FROM external_staging.erp_orders;
```

## Silver Layer: Cleaned and Typed

```sql
-- Create Silver table with proper types
CREATE TABLE "s3tablescatalog/analytics-lakehouse".silver.orders (
    order_id BIGINT,
    customer_id BIGINT,
    product_id BIGINT,
    amount DECIMAL(10,2),
    order_date DATE,
    source_system STRING,
    processed_at TIMESTAMP
)
TBLPROPERTIES ('table_type' = 'ICEBERG');
```

### Silver Transformation (Spark on EMR/Glue)

```python
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder \
    .config("spark.sql.catalog.lake",
            "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.lake.catalog-impl",
            "software.amazon.s3tables.iceberg.S3TablesCatalog") \
    .config("spark.sql.catalog.lake.warehouse",
            "arn:aws:s3tables:us-east-1:123456789012:bucket/analytics-lakehouse") \
    .getOrCreate()

# Read Bronze
bronze_df = spark.table("lake.bronze.raw_orders")

# Transform to Silver
silver_df = (
    bronze_df
    .dropDuplicates(["order_id"])
    .withColumn("amount", F.col("amount").cast("decimal(10,2)"))
    .withColumn("order_date", F.to_date("order_date", "yyyy-MM-dd"))
    .filter(F.col("order_id").isNotNull() & F.col("amount").isNotNull())
    .withColumn("processed_at", F.current_timestamp())
)

# Write to Silver (merge for incremental)
silver_df.createOrReplaceTempView("silver_updates")
spark.sql("""
    MERGE INTO lake.silver.orders t
    USING silver_updates s
    ON t.order_id = s.order_id
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
```

## Gold Layer: Business Aggregations

```sql
-- Create Gold aggregation table
CREATE TABLE "s3tablescatalog/analytics-lakehouse".gold.daily_revenue (
    report_date DATE,
    product_id BIGINT,
    total_revenue DECIMAL(12,2),
    order_count BIGINT,
    avg_order_value DECIMAL(10,2)
)
TBLPROPERTIES ('table_type' = 'ICEBERG');

-- Populate from Silver
INSERT OVERWRITE "s3tablescatalog/analytics-lakehouse".gold.daily_revenue
SELECT
    order_date as report_date,
    product_id,
    SUM(amount) as total_revenue,
    COUNT(*) as order_count,
    AVG(amount) as avg_order_value
FROM "s3tablescatalog/analytics-lakehouse".silver.orders
GROUP BY order_date, product_id;
```

## New Features for Medallion (Dec 2025)

- **Intelligent-Tiering**: Auto-tiers table data by access pattern. Bronze data naturally moves to cheaper tiers as it ages, reducing costs without manual lifecycle rules.
- **Cross-Region Replication**: Read-only replicas across regions/accounts for DR and low-latency reads. Writes must occur on the source table bucket.

## S3 Tables vs Self-Managed Medallion

| Aspect | S3 Tables Medallion | Self-Managed (S3 + Iceberg) |
|--------|--------------------|-----------------------------|
| Compaction | Automatic (including sort/z-order) | Manual Spark jobs per layer |
| Snapshot cleanup | Automatic | `expire_snapshots` procedures |
| Catalog | Built-in Glue integration | Manual Glue Crawler or HMS |
| File management | Fully managed | Monitor small files manually |
| ACID guarantees | Built-in | Requires Iceberg properly configured |
| Storage optimization | Intelligent-Tiering (Dec 2025) | Manual lifecycle rules |
| DR / multi-region | Cross-region replication (Dec 2025) | Manual CRR setup |
| Cost | S3 Tables pricing | S3 Standard + compute for maintenance |

## Maintenance per Layer

Configure compaction target file size per layer: Bronze 512 MB (large files, fewer scans), Silver 256 MB (balanced), Gold 128 MB (smaller datasets, frequent compaction). See `concepts/maintenance-compaction.md` for API examples.

## Best Practices

- Use separate namespaces per layer (not separate table buckets)
- Keep Bronze types loose (STRING) for schema evolution tolerance
- Use MERGE INTO for Silver incremental updates (deduplication)
- Configure compaction per layer based on data volume
- Use time travel on Bronze for reprocessing failed Silver transforms

## Related

- [../concepts/maintenance-compaction](../concepts/maintenance-compaction.md)
- [../concepts/table-buckets-namespaces](../concepts/table-buckets-namespaces.md)
- [analytics-integration](analytics-integration.md)
- [../../s3/patterns/data-lake-pattern](../../s3/patterns/data-lake-pattern.md)
