# Performance Optimization

> **Purpose**: Clustering, caching, materialized views, and Dynamic Tables for query performance
> **MCP Validated**: 2026-02-19

## When to Use

- Large tables with predictable filter/join columns
- Repeated queries on the same data (leverage caching)
- Dashboard aggregations on massive datasets (materialized views)
- Reducing scan times on multi-billion row tables
- Declarative incremental pipelines (Dynamic Tables with `CLUSTER BY`)

## Implementation

```sql
-- CLUSTERING: Organize data by frequently filtered columns
-- Best for: High-cardinality columns used in WHERE/JOIN
CREATE TABLE orders (
  order_id NUMBER,
  customer_id NUMBER,
  order_date DATE,
  region VARCHAR,
  amount DECIMAL(10,2)
)
CLUSTER BY (order_date, region);

-- Add clustering to existing table
ALTER TABLE orders CLUSTER BY (order_date, customer_id);

-- Check clustering depth (lower is better)
SELECT SYSTEM$CLUSTERING_DEPTH('orders');
SELECT SYSTEM$CLUSTERING_INFORMATION('orders');

-- MATERIALIZED VIEWS: Pre-computed aggregations (Enterprise+)
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
  order_date,
  region,
  COUNT(*) AS order_count,
  SUM(amount) AS total_amount,
  AVG(amount) AS avg_amount
FROM orders
GROUP BY order_date, region;

-- Query uses MV automatically when beneficial
SELECT * FROM mv_daily_sales WHERE order_date > '2024-01-01';

-- SEARCH OPTIMIZATION: Point lookups on equality predicates
ALTER TABLE customers ADD SEARCH OPTIMIZATION ON EQUALITY(customer_id, email);

-- Check search optimization status
SHOW TABLES LIKE 'customers';
SELECT "search_optimization" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
```

## Configuration

| Optimization | Cost Model | Best For |
|--------------|------------|----------|
| Clustering | Storage reclustering | Range queries, joins on date/id |
| Materialized Views | Storage + maintenance | Repeated aggregations |
| Dynamic Tables | Warehouse compute + storage | Incremental pipelines, chained transforms |
| Search Optimization | Background service | Point lookups (=, IN) |
| Result Cache | Free (automatic) | Identical repeated queries |
| Warehouse Cache | Included in compute | Similar queries on same data |

## Example Usage

```sql
-- Optimize a slow dashboard query
-- Before: Full table scan on 500M rows
SELECT region, DATE_TRUNC('month', order_date) AS month, SUM(amount)
FROM orders WHERE order_date >= '2023-01-01'
GROUP BY 1, 2;

-- Step 1: Add clustering on filter columns
ALTER TABLE orders CLUSTER BY (order_date, region);

-- Step 2: Create materialized view for dashboard
CREATE MATERIALIZED VIEW mv_regional_monthly_sales AS
SELECT
  region,
  DATE_TRUNC('month', order_date) AS month,
  SUM(amount) AS total_amount
FROM orders
GROUP BY 1, 2;

-- Step 3: Extend warehouse cache with longer auto-suspend
ALTER WAREHOUSE bi_wh SET AUTO_SUSPEND = 600;  -- 10 minutes

-- Monitor query performance
SELECT
  query_id,
  query_text,
  total_elapsed_time / 1000 AS seconds,
  bytes_scanned / 1e9 AS gb_scanned,
  partitions_scanned,
  partitions_total
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%orders%'
ORDER BY start_time DESC
LIMIT 20;

-- Check if query used result cache
SELECT query_id, bytes_scanned, bytes_written_to_result
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_id = '<query_id>';
-- bytes_scanned = 0 means result cache was used

-- DYNAMIC TABLES: Declarative incremental pipelines (cluster_by Nov 2025)
-- Replace complex task-based ETL with declarative definitions
CREATE DYNAMIC TABLE silver_orders
  TARGET_LAG = '30 minutes'    -- Refresh within 30 min of source change
  WAREHOUSE = transform_wh
  CLUSTER BY (order_date)       -- Automatic reclustering on refresh
  AS
  SELECT
    order_id, customer_id, order_date,
    amount, region,
    CURRENT_TIMESTAMP() AS processed_at
  FROM bronze_raw_orders
  WHERE amount > 0 AND order_date IS NOT NULL;

-- Chain Dynamic Tables for medallion architecture
CREATE DYNAMIC TABLE gold_daily_metrics
  TARGET_LAG = '1 hour'
  WAREHOUSE = analytics_wh
  CLUSTER BY (metric_date)
  AS
  SELECT
    order_date AS metric_date,
    region,
    COUNT(*) AS order_count,
    SUM(amount) AS revenue
  FROM silver_orders
  GROUP BY 1, 2;

-- Monitor Dynamic Table refresh history
SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
  NAME => 'silver_orders'
)) ORDER BY refresh_start_time DESC LIMIT 10;
```

## See Also

- [virtual-warehouses](../concepts/virtual-warehouses.md)
- [tables-views](../concepts/tables-views.md)
