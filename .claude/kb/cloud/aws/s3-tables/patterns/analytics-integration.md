# Analytics Engine Integration

> **Purpose**: Connect S3 Tables with Athena, Redshift, EMR, Glue via SageMaker Lakehouse
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 Tables integrate with AWS analytics services through **AWS Glue Data Catalog** and **SageMaker Lakehouse**. Integration creates a federated catalog (`s3tablescatalog`) that maps table buckets → catalogs, namespaces → databases, and tables → Glue tables.

## Integration Setup

### Step 1: Enable Analytics Integration

When creating a table bucket via the S3 console, check **"Enable integration with AWS analytics services"**. This automatically:

1. Creates `s3tablescatalog` federated catalog in Glue Data Catalog
2. Registers the table bucket as a Lake Formation data location
3. Configures IAM roles for cross-service access

### Step 2: Manual Integration (CLI/API)

If you created the table bucket via CLI, integrate manually:

```bash
# Register with Glue Data Catalog (creates s3tablescatalog)
aws glue create-catalog \
  --name my-analytics-bucket \
  --catalog-input '{
    "FederatedCatalog": {
      "Identifier": "arn:aws:s3tables:us-east-1:123456789012:bucket/my-analytics-bucket",
      "ConnectionName": "aws:s3tables"
    }
  }'
```

## Amazon Athena

```sql
-- Reference: "s3tablescatalog/{bucket-name}".{namespace}.{table}

-- Create database (namespace)
CREATE DATABASE "s3tablescatalog/my-analytics-bucket".sales;

-- Create table
CREATE TABLE "s3tablescatalog/my-analytics-bucket".sales.orders (
    order_id BIGINT,
    customer_id BIGINT,
    amount DECIMAL(10,2),
    order_date DATE
)
TBLPROPERTIES ('table_type' = 'ICEBERG');

-- Insert data
INSERT INTO "s3tablescatalog/my-analytics-bucket".sales.orders
VALUES (1, 1001, 299.99, DATE '2026-02-12');

-- Query
SELECT * FROM "s3tablescatalog/my-analytics-bucket".sales.orders
WHERE order_date >= DATE '2026-01-01';

-- CTAS (Create Table As Select)
CREATE TABLE "s3tablescatalog/my-analytics-bucket".sales.high_value_orders
WITH (format = 'PARQUET')
AS SELECT * FROM "s3tablescatalog/my-analytics-bucket".sales.orders
WHERE amount > 1000;
```

## Amazon Redshift

```sql
-- Redshift queries S3 Tables via Glue integration (read + write)
-- Must have Glue Data Catalog integration configured

SELECT order_id, amount
FROM "s3tablescatalog/my-analytics-bucket".sales.orders
WHERE amount > 100;

-- Cross-join S3 Tables with Redshift native tables
SELECT o.order_id, c.name, o.amount
FROM "s3tablescatalog/my-analytics-bucket".sales.orders o
JOIN customers c ON o.customer_id = c.id;
```

## Amazon EMR (Spark)

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("S3TablesAnalytics") \
    .config("spark.sql.catalog.s3tablesbucket",
            "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.s3tablesbucket.catalog-impl",
            "software.amazon.s3tables.iceberg.S3TablesCatalog") \
    .config("spark.sql.catalog.s3tablesbucket.warehouse",
            "arn:aws:s3tables:us-east-1:123456789012:bucket/my-analytics-bucket") \
    .getOrCreate()

# Read table
df = spark.sql("SELECT * FROM s3tablesbucket.sales.orders")

# Write data
df.writeTo("s3tablesbucket.sales.orders").append()

# Create table via Spark
spark.sql("""
    CREATE TABLE s3tablesbucket.sales.products (
        product_id BIGINT,
        name STRING,
        price DECIMAL(10,2)
    ) USING iceberg
""")
```

## AWS Glue ETL

```python
# Glue job reading/writing S3 Tables
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.sql.catalog.s3tablesbucket",
            "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.s3tablesbucket.catalog-impl",
            "software.amazon.s3tables.iceberg.S3TablesCatalog") \
    .config("spark.sql.catalog.s3tablesbucket.warehouse",
            "arn:aws:s3tables:us-east-1:123456789012:bucket/my-bucket") \
    .getOrCreate()

# Transform Bronze → Silver
bronze_df = spark.sql("SELECT * FROM s3tablesbucket.raw.events")
silver_df = bronze_df.dropDuplicates(["event_id"]).filter("event_type IS NOT NULL")
silver_df.writeTo("s3tablesbucket.curated.events").overwritePartitions()
```

## SageMaker Unified Studio Integration

SageMaker Unified Studio provides notebook-based access to S3 Tables for data exploration and ML workflows:

- Browse table buckets and namespaces directly in Studio
- Query S3 Tables via Spark or SQL notebooks
- Use Lake Formation permissions for fine-grained access control
- Integrated with the `s3tablescatalog` federated catalog

Access S3 Tables from Studio notebooks using the same Spark configuration shown in the EMR section above.

## Engine Capabilities Matrix

| Engine | Read | Write | DDL | Time Travel | Streaming |
|--------|------|-------|-----|-------------|-----------|
| Athena | Yes | Yes | Yes | Yes | No |
| Redshift | Yes | Yes | No | No | No |
| EMR Spark | Yes | Yes | Yes | Yes | Yes |
| Glue Spark | Yes | Yes | Yes | Yes | Yes |
| PyIceberg | Yes | Yes | Yes | Yes | No |
| SageMaker Studio | Yes | Yes | Yes | Yes | No |
| Snowflake (IRCC) | Yes | No | No | No | No |

## Third-Party Access via REST Catalog

Any Iceberg-compatible engine can connect via the REST Catalog endpoint:

```
Endpoint: https://s3tables.{region}.amazonaws.com/iceberg
Auth: AWS SigV4 (signing-name: s3tables)
```

## Related

- [../concepts/iceberg-integration](../concepts/iceberg-integration.md)
- [../concepts/security-access](../concepts/security-access.md)
- [data-lake-medallion](data-lake-medallion.md)
