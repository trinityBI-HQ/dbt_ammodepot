# Tables and Views

> **Purpose**: External tables, views, CTAS, and materialization strategies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Athena tables are external -- they define schema over data that lives in S3. Athena never moves or copies the underlying data. Tables are registered in the Glue Data Catalog and can be queried from Athena, Redshift Spectrum, EMR, and Glue ETL.

## External Tables

```sql
-- Create external table pointing to S3 Parquet data
CREATE EXTERNAL TABLE sales_db.orders (
    order_id    STRING,
    customer_id STRING,
    amount      DECIMAL(10,2),
    status      STRING,
    created_at  TIMESTAMP
)
PARTITIONED BY (year STRING, month STRING)
STORED AS PARQUET
LOCATION 's3://data-lake/silver/orders/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');

-- Load partitions
MSCK REPAIR TABLE sales_db.orders;
```

## CTAS (Create Table As Select)

CTAS creates a new table from query results -- the primary way to transform and materialize data:

```sql
-- Convert JSON to Parquet with partitioning
CREATE TABLE sales_db.orders_optimized
WITH (
    format = 'PARQUET',
    parquet_compression = 'SNAPPY',
    partitioned_by = ARRAY['year', 'month'],
    external_location = 's3://data-lake/gold/orders/'
) AS
SELECT order_id, customer_id, amount, status, created_at,
    YEAR(created_at) AS year,
    LPAD(CAST(MONTH(created_at) AS VARCHAR), 2, '0') AS month
FROM sales_db.raw_orders
WHERE created_at >= DATE '2024-01-01';
```

**CTAS limits:** Result capped at 100 partitions. For more, use INSERT INTO or Glue ETL.

## INSERT INTO / UNLOAD

`INSERT INTO` appends data to existing tables. `UNLOAD` exports query results to S3 without creating table metadata (faster for pure exports):

## UNLOAD

Export query results to S3 in optimized formats:

```sql
UNLOAD (
    SELECT customer_id, SUM(amount) AS total_spend
    FROM sales_db.orders
    WHERE year = '2025'
    GROUP BY customer_id
)
TO 's3://exports/customer-spend/'
WITH (format = 'PARQUET', compression = 'SNAPPY');
```

UNLOAD is faster than CTAS for pure export (no table metadata created).

## Views

```sql
-- Standard view (query rewritten at execution)
CREATE VIEW sales_db.active_orders AS
SELECT * FROM sales_db.orders WHERE status IN ('pending', 'shipped');

-- Views don't store data; they're query aliases
-- Useful for: access control, simplifying complex joins, abstractions
```

## Materialized Views (Nov 2025+)

Athena can query Glue Data Catalog materialized views (Iceberg-backed, created via Glue 5.1+):

```sql
-- Query a materialized view like a regular table
SELECT * FROM sales_db.monthly_revenue_mv WHERE month >= '2025-01';
```

Precomputed results stored as Iceberg tables. Reduces cost by avoiding repeated expensive aggregations. Refresh can be automatic or manual.

## Iceberg Tables

```sql
-- Create Iceberg table for ACID operations
CREATE TABLE sales_db.customers (
    customer_id STRING,
    name        STRING,
    email       STRING,
    updated_at  TIMESTAMP
)
LOCATION 's3://data-lake/iceberg/customers/'
TBLPROPERTIES ('table_type' = 'ICEBERG');

-- Iceberg supports UPDATE, DELETE, MERGE
UPDATE sales_db.customers SET email = 'new@example.com' WHERE customer_id = 'c-123';
DELETE FROM sales_db.customers WHERE updated_at < DATE '2020-01-01';
```

## Quick Reference

| Operation | Creates Data? | Creates Metadata? |
|-----------|--------------|-------------------|
| CREATE EXTERNAL TABLE | No | Yes (Catalog only) |
| CTAS | Yes (S3) | Yes (Catalog + S3) |
| INSERT INTO | Yes (S3) | Updates partitions |
| UNLOAD | Yes (S3) | No |
| CREATE VIEW | No | Yes (Catalog only) |

## Common Mistakes

### Wrong

```sql
-- MSCK REPAIR on table with thousands of partitions = slow
MSCK REPAIR TABLE huge_table;  -- Scans all S3 prefixes
```

### Correct

```sql
-- Add partitions explicitly for known data
ALTER TABLE huge_table ADD
    PARTITION (year='2025', month='06') LOCATION 's3://lake/data/year=2025/month=06/';
-- Or use partition projection to eliminate MSCK entirely
```

## Related

- [Data Formats](../concepts/data-formats.md)
- [Partitions](../concepts/partitions.md)
