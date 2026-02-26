# Tables and Views

> **Purpose**: Core data storage structures, dynamic tables, and virtual query abstractions
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Tables store data in Snowflake using automatic micro-partitions (50-500MB columnar units). Views are named SQL queries that do not store data. Snowflake supports permanent tables, transient tables (no fail-safe), temporary tables (session-scoped), and materialized views (pre-computed and cached).

## The Pattern

```sql
-- Standard table with clustering
CREATE TABLE orders (
  order_id NUMBER AUTOINCREMENT,
  customer_id NUMBER NOT NULL,
  order_date DATE,
  amount DECIMAL(10,2),
  metadata VARIANT,
  created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (order_date, customer_id);

-- Transient table (no fail-safe, lower storage cost)
CREATE TRANSIENT TABLE staging_orders LIKE orders;

-- Temporary table (session-scoped)
CREATE TEMPORARY TABLE temp_results AS
SELECT * FROM orders WHERE order_date = CURRENT_DATE();

-- Standard view
CREATE VIEW v_recent_orders AS
SELECT * FROM orders WHERE order_date > DATEADD(day, -30, CURRENT_DATE());

-- Secure view (hides definition from non-owners)
CREATE SECURE VIEW v_customer_orders AS
SELECT customer_id, SUM(amount) as total
FROM orders GROUP BY customer_id;

-- Materialized view (Enterprise+)
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT order_date, SUM(amount) as daily_total
FROM orders GROUP BY order_date;

-- Dynamic Table (declarative pipeline with incremental refresh)
CREATE DYNAMIC TABLE orders_enriched
  TARGET_LAG = '1 hour'
  WAREHOUSE = transform_wh
  CLUSTER BY (order_date)  -- cluster_by support (Nov 2025)
  AS
  SELECT o.*, c.segment, c.region
  FROM orders o JOIN customers c ON o.customer_id = c.id;

-- Dynamic Table with Cortex AI (Sep 2025)
CREATE DYNAMIC TABLE orders_classified
  TARGET_LAG = '1 hour'
  WAREHOUSE = ai_wh
  AS
  SELECT
    order_id,
    description,
    AI_CLASSIFY(description, ['electronics', 'clothing', 'food']) AS category,
    AI_SENTIMENT(feedback) AS sentiment_score
  FROM orders_enriched;
```

## Quick Reference

| Table Type | Time Travel | Fail-Safe | Scope |
|------------|-------------|-----------|-------|
| Permanent | Yes (1-90 days) | 7 days | Persistent |
| Transient | Yes (0-1 day) | None | Persistent |
| Temporary | Yes (0-1 day) | None | Session |
| External | No | No | Persistent |

| View Type | Stores Data | Use Case |
|-----------|-------------|----------|
| Standard | No | Query abstraction |
| Secure | No | Hide logic, data sharing |
| Materialized | Yes | Pre-computed aggregates |
| Dynamic Table | Yes | Declarative incremental pipelines |

## Common Mistakes

### Wrong

```sql
-- Clustering on low-cardinality column
CREATE TABLE logs (...) CLUSTER BY (log_level);  -- Only 5 values

-- Materialized view on frequently changing base table
CREATE MATERIALIZED VIEW mv AS
SELECT * FROM high_churn_table;  -- Expensive maintenance
```

### Correct

```sql
-- Cluster on high-cardinality filter/join columns
CREATE TABLE logs (...) CLUSTER BY (event_timestamp, user_id);

-- Materialized view for stable aggregations
CREATE MATERIALIZED VIEW mv_monthly_metrics AS
SELECT DATE_TRUNC('month', created_at) as month, COUNT(*) as cnt
FROM events GROUP BY 1;

-- Dynamic Table with appropriate lag and clustering
CREATE DYNAMIC TABLE daily_metrics
  TARGET_LAG = '30 minutes'
  WAREHOUSE = transform_wh
  CLUSTER BY (metric_date)
  AS SELECT metric_date, SUM(value) as total FROM raw_metrics GROUP BY 1;
```

## Related

- [databases-schemas](../concepts/databases-schemas.md)
- [performance-optimization](../patterns/performance-optimization.md)
