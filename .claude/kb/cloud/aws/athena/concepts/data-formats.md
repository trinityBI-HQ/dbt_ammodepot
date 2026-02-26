# Data Formats

> **Purpose**: Choose the right storage format for cost and performance
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Athena's cost is $5/TB scanned, so the data format directly impacts both cost and query speed. Columnar formats (Parquet, ORC) dramatically reduce scans by reading only needed columns. Format choice is the single biggest optimization lever for Athena.

## Format Comparison

| Format | Type | Compression | Column Pruning | Predicate Pushdown | Best For |
|--------|------|-------------|---------------|-------------------|----------|
| **Parquet** | Columnar | Snappy, GZIP, ZSTD | Yes | Yes | Default choice for analytics |
| **ORC** | Columnar | ZLIB, Snappy, LZ4 | Yes | Yes | Hive ecosystem |
| **Avro** | Row | Snappy, Deflate | No | No | Schema evolution, streaming |
| **JSON** | Row | GZIP | No | No | Logs, semi-structured |
| **CSV/TSV** | Row | GZIP | No | No | Simple, interoperable |
| **Ion** | Row | None | No | No | AWS-native format |

## Cost Impact Example

Scanning a 1 TB table with 100 columns, querying 5 columns:

| Format | Data Scanned | Cost |
|--------|-------------|------|
| CSV (uncompressed) | 1 TB | $5.00 |
| CSV (GZIP) | ~250 GB | $1.25 |
| Parquet (Snappy) | ~15 GB | $0.075 |

**Parquet is 65x cheaper than raw CSV** for typical analytical queries.

## Parquet Best Practices

```sql
-- Create optimized Parquet table
CREATE TABLE sales_db.orders_parquet
WITH (
    format = 'PARQUET',
    parquet_compression = 'SNAPPY',      -- Best speed/ratio balance
    partitioned_by = ARRAY['year', 'month'],
    external_location = 's3://lake/orders-parquet/',
    bucketed_by = ARRAY['customer_id'],  -- Co-locate related rows
    bucket_count = 32
) AS SELECT * FROM sales_db.raw_orders;
```

**Compression options:**
| Compression | Ratio | Speed | Use When |
|-------------|-------|-------|----------|
| SNAPPY | Good | Fastest | Default choice, interactive queries |
| ZSTD | Better | Fast | Balance of size and speed |
| GZIP | Best | Slow | Cold storage, batch queries |

## Working with JSON

```sql
-- Create table over JSON logs
CREATE EXTERNAL TABLE logs_db.app_logs (
    timestamp STRING,
    level     STRING,
    message   STRING,
    metadata  MAP<STRING, STRING>
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
WITH SERDEPROPERTIES ('ignore.malformed.json' = 'true')
LOCATION 's3://logs/app/'
TBLPROPERTIES ('compressionType' = 'gzip');

-- Query nested JSON with dot notation
SELECT timestamp, metadata['user_id'] AS user_id
FROM logs_db.app_logs
WHERE level = 'ERROR';
```

**Tip:** Convert JSON to Parquet for repeated queries:
```sql
CREATE TABLE logs_db.app_logs_parquet
WITH (format='PARQUET', parquet_compression='SNAPPY')
AS SELECT * FROM logs_db.app_logs;
```

## Working with CSV

```sql
CREATE EXTERNAL TABLE sales_db.imports (
    id       INT,
    name     STRING,
    amount   DOUBLE
)
ROW FORMAT DELIMITED
    FIELDS TERMINATED BY ','
    ESCAPED BY '\\'
    LINES TERMINATED BY '\n'
LOCATION 's3://imports/data/'
TBLPROPERTIES ('skip.header.line.count' = '1');
```

## Apache Iceberg Format

Iceberg provides ACID transactions over Parquet/ORC files:

```sql
CREATE TABLE sales_db.customers (
    id STRING, name STRING, email STRING, updated_at TIMESTAMP
)
LOCATION 's3://lake/iceberg/customers/'
TBLPROPERTIES ('table_type' = 'ICEBERG');
```

**Iceberg advantages over plain Parquet:**
- UPDATE, DELETE, MERGE operations
- Time travel queries
- Schema evolution without rewriting data
- Hidden partitioning (no user-facing partition columns)

## File Size Guidelines

| Guideline | Value | Why |
|-----------|-------|-----|
| Target file size | 128 MB - 512 MB | Balance parallelism and overhead |
| Minimum file size | 32 MB | Avoid small-file penalty |
| Max files per partition | ~10,000 | S3 listing performance |

Too many small files = slow (S3 listing overhead). Too few large files = poor parallelism.

## Common Mistakes

### Wrong

```sql
-- Querying raw JSON daily = expensive
SELECT user_id, COUNT(*) FROM json_logs GROUP BY user_id;
```

### Correct

```sql
-- Convert to Parquet once, query cheaply forever
CREATE TABLE parquet_logs WITH (format='PARQUET') AS SELECT * FROM json_logs;
SELECT user_id, COUNT(*) FROM parquet_logs GROUP BY user_id;
```

## Related

- [Tables and Views](../concepts/tables-views.md)
- [Query Optimization](../patterns/query-optimization.md)
