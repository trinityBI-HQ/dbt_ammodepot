# Interactive Tables and Interactive Warehouses

> **Purpose**: Low-latency, high-concurrency analytics with sub-second query response times
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-25

## Overview

Interactive Tables and Interactive Warehouses are a specialized pair of Snowflake objects optimized for low-latency, high-concurrency workloads. Interactive Tables store data in row-oriented structures with built-in indexing, while Interactive Warehouses run continuously with SSD caching. Together they deliver consistent sub-second query latency for real-time dashboards, APIs, and point lookups. GA since December 11, 2025.

## The Pattern

```sql
-- Step 1: Create an Interactive Table (requires CLUSTER BY)
CREATE INTERACTIVE TABLE dashboard_metrics
  CLUSTER BY (metric_date, region)
  AS
  SELECT metric_date, region, product_id, revenue, order_count
  FROM gold.daily_metrics;

-- Step 2: Create a Dynamic Interactive Table (auto-refresh)
CREATE INTERACTIVE TABLE live_orders
  CLUSTER BY (customer_id, order_date)
  TARGET_LAG = '5 minutes'
  WAREHOUSE = refresh_wh  -- Must be a standard warehouse
  AS
  SELECT order_id, customer_id, order_date, status, total_amount
  FROM silver.orders
  WHERE order_date >= DATEADD(day, -30, CURRENT_DATE());

-- Step 3: Create an Interactive Warehouse and assign tables
CREATE INTERACTIVE WAREHOUSE dashboard_iwh
  WAREHOUSE_SIZE = 'XSMALL'
  TABLES (dashboard_metrics, live_orders);

-- Resume the warehouse (created in SUSPENDED state)
ALTER WAREHOUSE dashboard_iwh RESUME;

-- Step 4: Query with sub-second latency
USE WAREHOUSE dashboard_iwh;
SELECT * FROM dashboard_metrics
WHERE metric_date = '2026-02-25' AND region = 'US-EAST';

-- Manual data refresh (static interactive tables)
INSERT OVERWRITE INTO dashboard_metrics
SELECT metric_date, region, product_id, revenue, order_count
FROM gold.daily_metrics;
```

## Quick Reference

| Feature | Interactive Table | Standard Table |
|---------|------------------|----------------|
| Storage format | Row-oriented with indexing | Columnar micro-partitions |
| CLUSTER BY | Required | Optional |
| DML operations | INSERT OVERWRITE only | Full DML |
| Time Travel | Yes | Yes |
| Fail-safe | No | Yes (permanent tables) |
| ALTER COLUMN | No | Yes |
| Streams/Dynamic Tables | Not compatible | Compatible |

| Interactive WH Size | Working Dataset | Credits/Hr (approx) |
|---------------------|-----------------|---------------------|
| XSMALL | < 500 GB | ~0.6 |
| SMALL | 500 GB - 1 TB | ~1.2 |
| MEDIUM | 1 - 2 TB | ~2.4 |
| LARGE | 2 - 4 TB | ~4.8 |
| XLARGE | 4 - 8 TB | ~9.6 |
| 2XLARGE | 8 - 16 TB | ~19.2 |
| 3XLARGE | > 16 TB | ~38.4 |

| Parameter | Value | Notes |
|-----------|-------|-------|
| Query timeout | 5 seconds max | Cannot be increased |
| TARGET_LAG minimum | 60 seconds | For dynamic interactive tables |
| Billing minimum | 1 hour | Then per-second granularity |
| Multi-cluster scaling | Manual only | MIN = MAX cluster count |

## Common Mistakes

### Wrong

```sql
-- Trying to UPDATE an interactive table
UPDATE dashboard_metrics SET revenue = 0 WHERE region = 'TEST';
-- ERROR: Only INSERT OVERWRITE is supported

-- Querying standard tables with an interactive warehouse
USE WAREHOUSE dashboard_iwh;
SELECT * FROM standard_table;
-- ERROR: Interactive warehouses can only query interactive tables

-- Creating without CLUSTER BY
CREATE INTERACTIVE TABLE bad_table AS SELECT * FROM source;
-- ERROR: CLUSTER BY is required
```

### Correct

```sql
-- Use INSERT OVERWRITE for data updates
INSERT OVERWRITE INTO dashboard_metrics
SELECT * FROM gold.daily_metrics WHERE metric_date >= '2026-01-01';

-- Use TARGET_LAG for automatic refresh
CREATE INTERACTIVE TABLE auto_refresh_metrics
  CLUSTER BY (metric_date)
  TARGET_LAG = '2 minutes'
  WAREHOUSE = standard_wh
  AS SELECT * FROM gold.daily_metrics;

-- Size warehouse to working dataset, not query complexity
CREATE INTERACTIVE WAREHOUSE api_iwh
  WAREHOUSE_SIZE = 'SMALL'  -- 500GB-1TB dataset
  TABLES (api_lookup_table);
```

## Related

- [virtual-warehouses](../concepts/virtual-warehouses.md)
- [tables-views](../concepts/tables-views.md)
- [interactive-analytics](../patterns/interactive-analytics.md)
