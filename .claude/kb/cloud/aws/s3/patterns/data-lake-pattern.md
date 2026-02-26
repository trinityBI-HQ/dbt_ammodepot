# S3 Data Lake Pattern

> **Purpose**: S3 as data lake foundation with medallion layers (Bronze/Silver/Gold)
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Amazon S3 is the standard foundation for AWS data lakes. The medallion architecture (Bronze → Silver → Gold) organizes data into progressive quality layers, queried via Athena, Glue, and Redshift Spectrum.

## Bucket Structure

```
s3://company-datalake-{env}/
├── bronze/                          # Raw ingestion
│   └── {source_system}/
│       └── {entity}/
│           └── year=YYYY/month=MM/day=DD/
├── silver/                          # Cleaned, conformed
│   └── {domain}/
│       └── {entity}/
│           └── year=YYYY/month=MM/
└── gold/                            # Business aggregations
    └── {use_case}/
        └── {metric}/
```

## Layer Definitions

| Layer | Format | Schema | Retention | Query Engine |
|-------|--------|--------|-----------|-------------|
| Bronze | Source format (CSV, JSON, Parquet) | Schema-on-read | 1-7 years | Athena, Glue |
| Silver | Parquet / Iceberg | Enforced, typed | 1-3 years | Athena, Redshift Spectrum |
| Gold | Parquet / Iceberg | Star schema | Rolling window | Athena, QuickSight |

## Implementation

### Bronze Ingestion (Glue Job)

```python
import sys
from awsglue.context import GlueContext
from pyspark.context import SparkContext

sc = SparkContext()
glue_context = GlueContext(sc)

# Read from source
source_df = glue_context.create_dynamic_frame.from_catalog(
    database="raw_db",
    table_name="orders_raw",
)

# Write to Bronze with Hive partitioning
glue_context.write_dynamic_frame.from_options(
    frame=source_df,
    connection_type="s3",
    connection_options={
        "path": "s3://datalake/bronze/erp/orders/",
        "partitionKeys": ["year", "month", "day"],
    },
    format="parquet",
)
```

### Silver Transformation

```python
from pyspark.sql import functions as F

bronze_df = spark.read.parquet("s3://datalake/bronze/erp/orders/")

silver_df = (
    bronze_df
    .dropDuplicates(["order_id"])
    .withColumn("order_date", F.to_date("order_date_str", "yyyy-MM-dd"))
    .withColumn("amount", F.col("amount").cast("decimal(10,2)"))
    .filter(F.col("order_id").isNotNull())
)

silver_df.write.mode("overwrite").partitionBy("year", "month").parquet(
    "s3://datalake/silver/sales/orders/"
)
```

### Gold Aggregation

```python
gold_df = (
    spark.read.parquet("s3://datalake/silver/sales/orders/")
    .groupBy("year", "month", "product_category")
    .agg(
        F.sum("amount").alias("total_revenue"),
        F.countDistinct("customer_id").alias("unique_customers"),
        F.count("order_id").alias("order_count"),
    )
)

gold_df.write.mode("overwrite").parquet(
    "s3://datalake/gold/sales/monthly_revenue/"
)
```

## Athena Querying

```sql
-- Query Gold layer directly from S3
SELECT product_category, total_revenue, unique_customers
FROM gold_db.monthly_revenue
WHERE year = '2026' AND month = '01'
ORDER BY total_revenue DESC;
```

## Terraform: Data Lake Buckets

```hcl
resource "aws_s3_bucket" "datalake" {
  bucket = "company-datalake-${var.environment}"
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "bronze-to-ia"
    status = "Enabled"
    filter { prefix = "bronze/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}
```

## Best Practices

| Practice | Why |
|----------|-----|
| Use Hive-style partitioning (`year=2026/month=02`) | Enables partition pruning in Athena/Glue |
| Store Silver/Gold as Parquet or Iceberg | Columnar format, compression, schema evolution |
| Separate buckets per environment | Isolate dev/staging/prod access |
| Enable versioning on Bronze | Reprocessing capability |
| Use Glue Data Catalog | Centralized metadata for all query engines |
| Apply lifecycle rules | Transition older Bronze data to IA/Glacier |

## Anti-Patterns

- Storing Gold data as CSV (use Parquet for query performance)
- Skipping Silver layer (leads to duplicated transformation logic)
- No partitioning on large tables (causes full-scan queries in Athena)
- Using a single bucket with no prefix strategy (impossible to manage permissions)

## Related

- [../concepts/buckets-objects](../concepts/buckets-objects.md)
- [../concepts/storage-classes](../concepts/storage-classes.md)
- [performance-optimization](performance-optimization.md)
- [Dagster KB](../../../../data-engineering/orchestration/dagster/)
- [dbt KB](../../../../data-engineering/transformation/dbt/)
