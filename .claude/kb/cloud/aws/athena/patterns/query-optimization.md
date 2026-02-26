# Query Optimization

> **Purpose**: Minimize data scanned and maximize query performance
> **MCP Validated**: 2026-02-19

## When to Use

- Athena queries are slow or expensive
- Need to reduce per-query scan costs
- Optimizing frequently-run dashboard queries

## Optimization Priority Stack

```
1. Use columnar format (Parquet/ORC)     → 10-100x reduction
2. Partition pruning                       → 10-365x reduction
3. Column projection (SELECT specific)     → 2-20x reduction
4. Compression (Snappy/ZSTD)              → 2-4x reduction
5. File size optimization (128-512 MB)     → 1.5-3x speedup
6. Bucketing for frequent joins            → 2-5x join speedup
```

## Implementation

### 1. Convert to Parquet

```sql
-- One-time conversion from JSON/CSV to Parquet
CREATE TABLE optimized_db.events
WITH (
    format = 'PARQUET',
    parquet_compression = 'SNAPPY',
    partitioned_by = ARRAY['dt'],
    external_location = 's3://lake/optimized/events/'
) AS
SELECT event_id, user_id, event_type, payload,
    DATE_FORMAT(event_time, '%Y-%m-%d') AS dt
FROM raw_db.events;
```

### 2. Select Only Needed Columns

```sql
-- Bad: scans all 50 columns
SELECT * FROM orders WHERE year = '2025';

-- Good: scans only 3 columns (Parquet column pruning)
SELECT order_id, customer_id, amount
FROM orders WHERE year = '2025';
```

### 3. Use Partition Predicates

```sql
-- Bad: no partition filter, scans entire table
SELECT COUNT(*) FROM events WHERE event_type = 'purchase';

-- Good: partition pruning limits scan to 1 month
SELECT COUNT(*) FROM events
WHERE dt BETWEEN '2025-06-01' AND '2025-06-30'
  AND event_type = 'purchase';
```

### 4. Optimize Joins

```sql
-- Put larger table on LEFT side of join
-- Athena streams the right table into memory
SELECT o.order_id, c.name, o.amount
FROM orders o                          -- Large table (left)
JOIN customers c ON o.customer_id = c.id;  -- Small table (right)

-- For very large joins, use bucketed tables
CREATE TABLE orders_bucketed
WITH (
    format = 'PARQUET',
    bucketed_by = ARRAY['customer_id'],
    bucket_count = 32
) AS SELECT * FROM orders;
```

### 5. Use APPROXIMATE Functions

```sql
-- Exact count distinct (slow for large datasets)
SELECT COUNT(DISTINCT user_id) FROM events;

-- Approximate (HyperLogLog, much faster, ~2% error)
SELECT APPROX_DISTINCT(user_id) FROM events;

-- Approximate percentiles
SELECT APPROX_PERCENTILE(latency_ms, 0.99) AS p99 FROM requests;
```

### 6. Predicate Pushdown

```sql
-- Parquet/ORC store min/max stats per row group
-- Athena skips row groups where predicates can't match
SELECT * FROM orders
WHERE amount > 1000          -- Pushdown: skip row groups where max(amount) < 1000
  AND created_at > DATE '2025-01-01';  -- Pushdown on sorted data
```

## EXPLAIN for Query Analysis

```sql
EXPLAIN SELECT customer_id, SUM(amount)
FROM orders WHERE year = '2025'
GROUP BY customer_id;

-- Look for:
-- - TableScan with "constraint" = partition pruning active
-- - Exchange = shuffle (expensive, minimize)
-- - TopN vs Sort = partial vs full sort
```

## Materialization Strategies

| Strategy | When | Implementation |
|----------|------|---------------|
| CTAS | One-time format conversion | `CREATE TABLE ... AS SELECT` |
| Scheduled CTAS | Daily aggregation tables | Step Functions + Athena |
| INSERT INTO | Incremental appends | Glue job → INSERT INTO |
| Views | Query simplification | `CREATE VIEW` (no cost savings) |
| Materialized Views | Expensive repeated aggregations | Glue Data Catalog materialized views (Nov 2025+) |

### Materialized Views (Nov 2025+)

Glue Data Catalog materialized views (Iceberg-backed) are queryable from Athena SQL. Use them for precomputed aggregations that would otherwise scan large amounts of data:

```sql
-- Query a materialized view like a regular table
SELECT region, total_revenue
FROM sales_db.monthly_revenue_mv
WHERE month = '2025-06';
-- Reads from precomputed Iceberg table instead of scanning raw data
```

```sql
-- Daily aggregation table (run via scheduler)
INSERT INTO gold_db.daily_metrics
SELECT DATE(created_at) AS metric_date,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue
FROM silver_db.orders
WHERE dt = '${today}'
GROUP BY 1;
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `parquet_compression` | GZIP | Use SNAPPY for speed |
| `orc_compression` | ZLIB | Use SNAPPY for speed |
| `bucket_count` | None | Powers of 2 (8, 16, 32, 64) |
| `write_compression` | None | For CTAS output |

## Example Usage

```python
# Python: run optimized query
import boto3

athena = boto3.client("athena")
athena.start_query_execution(
    QueryString="""
        SELECT customer_id, SUM(amount) AS total
        FROM orders
        WHERE year='2025' AND month='06'  -- Partition pruning
        GROUP BY customer_id
        ORDER BY total DESC
        LIMIT 100
    """,
    WorkGroup="analytics-team",
    QueryExecutionContext={"Database": "sales_db"},
)
```

## See Also

- [Data Formats](../concepts/data-formats.md)
- [Partitions](../concepts/partitions.md)
