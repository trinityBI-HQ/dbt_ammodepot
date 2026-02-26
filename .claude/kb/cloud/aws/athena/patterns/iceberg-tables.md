# Iceberg Tables

> **Purpose**: ACID transactions, time travel, and schema evolution on S3
> **MCP Validated**: 2026-02-19

## When to Use

- Need UPDATE/DELETE/MERGE on S3 data
- Regulatory requirement for data correction (GDPR right-to-delete)
- Want time travel for auditing or rollback
- Schema evolves frequently without breaking consumers
- Need consistent reads during concurrent writes

## Implementation

### Create Iceberg Table

```sql
CREATE TABLE sales_db.customers (
    customer_id  STRING,
    name         STRING,
    email        STRING,
    tier         STRING,
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP
)
PARTITIONED BY (BUCKET(16, customer_id))
LOCATION 's3://data-lake/iceberg/customers/'
TBLPROPERTIES (
    'table_type'        = 'ICEBERG',
    'format'            = 'PARQUET',
    'write_compression' = 'SNAPPY',
    'optimize_rewrite_delete_file_threshold' = '10'
);
```

### DML Operations

```sql
-- INSERT
INSERT INTO sales_db.customers
VALUES ('c-001', 'Alice', 'alice@example.com', 'gold', NOW(), NOW());

-- UPDATE
UPDATE sales_db.customers
SET tier = 'platinum', updated_at = NOW()
WHERE customer_id = 'c-001';

-- DELETE (GDPR compliance)
DELETE FROM sales_db.customers
WHERE customer_id = 'c-deleted-user';

-- MERGE (upsert)
MERGE INTO sales_db.customers AS target
USING sales_db.customers_staging AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE
    SET name = source.name, email = source.email, updated_at = NOW()
WHEN NOT MATCHED THEN INSERT
    VALUES (source.customer_id, source.name, source.email, 'bronze', NOW(), NOW());
```

### Time Travel

```sql
-- Query data as of a specific snapshot
SELECT * FROM sales_db.customers
FOR TIMESTAMP AS OF TIMESTAMP '2025-06-01 00:00:00';

-- Query by snapshot ID
SELECT * FROM sales_db.customers
FOR VERSION AS OF 12345678901234;

-- View snapshot history
SELECT * FROM "sales_db"."customers$snapshots"
ORDER BY committed_at DESC;

-- View file manifests
SELECT * FROM "sales_db"."customers$manifests";
```

### Schema Evolution

```sql
-- Add column (no rewrite needed)
ALTER TABLE sales_db.customers ADD COLUMNS (phone STRING);

-- Rename column
ALTER TABLE sales_db.customers CHANGE phone phone_number STRING;

-- Reorder columns
ALTER TABLE sales_db.customers CHANGE phone_number phone_number STRING AFTER email;
```

Iceberg handles schema evolution at the metadata level -- existing Parquet files are not rewritten.

## Hidden Partitioning

Iceberg partitions don't require user-facing columns:

```sql
-- Partition by year/month derived from timestamp
CREATE TABLE events (
    event_id STRING, user_id STRING, event_time TIMESTAMP, payload STRING
)
PARTITIONED BY (MONTH(event_time))  -- Hidden partition transform
LOCATION 's3://lake/iceberg/events/'
TBLPROPERTIES ('table_type' = 'ICEBERG');

-- Users query naturally -- no partition column in WHERE
SELECT * FROM events WHERE event_time > TIMESTAMP '2025-06-01';
-- Iceberg automatically applies partition pruning
```

| Transform | Description | Example |
|-----------|-------------|---------|
| `YEAR(ts)` | Year partition | 2025 |
| `MONTH(ts)` | Year-month | 2025-06 |
| `DAY(ts)` | Year-month-day | 2025-06-15 |
| `HOUR(ts)` | Year-month-day-hour | 2025-06-15-10 |
| `BUCKET(n, col)` | Hash bucket | Bucket 7 of 16 |
| `TRUNCATE(n, col)` | String prefix | "abc" → "ab" |

## Table Maintenance

```sql
-- Compact small files (critical for performance)
OPTIMIZE sales_db.customers REWRITE DATA
USING BIN_PACK;

-- Remove old snapshots (free storage)
ALTER TABLE sales_db.customers SET TBLPROPERTIES (
    'vacuum_max_snapshot_age_seconds' = '604800'  -- 7 days
);
VACUUM sales_db.customers;

-- Remove orphan files
ALTER TABLE sales_db.customers SET TBLPROPERTIES (
    'vacuum_min_snapshots_to_keep' = '5'
);
```

## Iceberg Format v3 (Glue 5.1+)

With Glue 5.1 shipping Iceberg 1.10.0, Athena gains access to Iceberg format v3 tables:

- **Nanosecond timestamp** precision (`TIMESTAMP_NTZ`)
- **Row-level lineage** tracking via default sort order
- **Multi-argument partition transforms**

Tables created with `'format-version' = '3'` in Glue 5.1 are queryable via Athena. Existing v1/v2 tables continue to work unchanged.

## Iceberg vs Plain Parquet

| Feature | Parquet | Iceberg |
|---------|---------|---------|
| SELECT | Yes | Yes |
| INSERT | Append only | Yes |
| UPDATE/DELETE | No | Yes |
| MERGE | No | Yes |
| Time travel | No | Yes |
| Schema evolution | Risky | Safe |
| Hidden partitions | No | Yes |
| ACID transactions | No | Yes |
| File compaction | Manual ETL | OPTIMIZE command |

**Use plain Parquet for:** append-only tables, simple data lakes.
**Use Iceberg for:** mutable data, audit requirements, complex pipelines.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `format` | PARQUET | Underlying file format |
| `write_compression` | GZIP | SNAPPY recommended |
| `optimize_rewrite_delete_file_threshold` | 10 | Auto-compact threshold |
| `vacuum_max_snapshot_age_seconds` | 432000 (5 days) | Snapshot retention |

## See Also

- [Tables and Views](../concepts/tables-views.md)
- [Data Formats](../concepts/data-formats.md)
