# Interactive Analytics Pattern

> **Purpose**: Implementing low-latency dashboards, APIs, and point lookups with Interactive Tables and Warehouses
> **MCP Validated**: 2026-02-25

## When to Use

- Real-time dashboards requiring sub-second response times
- Data-powered REST APIs serving concurrent users
- Point lookups by key (customer ID, order ID, SKU)
- High-concurrency workloads (thousands of simultaneous queries)
- Embedded analytics in customer-facing applications

## Implementation

```sql
-- Pattern 1: Static Interactive Table for reporting
-- Best for: data refreshed on a schedule (hourly/daily)
CREATE INTERACTIVE TABLE reporting.customer_360
  CLUSTER BY (customer_id)
  AS
  SELECT
    c.customer_id,
    c.name,
    c.email,
    c.segment,
    c.region,
    o.total_orders,
    o.total_revenue,
    o.last_order_date,
    o.avg_order_value
  FROM gold.d_customer c
  JOIN gold.f_customer_summary o ON c.customer_id = o.customer_id;

-- Refresh via scheduled INSERT OVERWRITE (e.g., in dbt or task)
INSERT OVERWRITE INTO reporting.customer_360
SELECT c.customer_id, c.name, c.email, c.segment, c.region,
       o.total_orders, o.total_revenue, o.last_order_date, o.avg_order_value
FROM gold.d_customer c
JOIN gold.f_customer_summary o ON c.customer_id = o.customer_id;

-- Pattern 2: Dynamic Interactive Table (auto-refresh)
-- Best for: near-real-time data with automatic updates
CREATE INTERACTIVE TABLE reporting.live_inventory
  CLUSTER BY (product_id, warehouse_id)
  TARGET_LAG = '2 minutes'
  WAREHOUSE = refresh_wh
  AS
  SELECT
    product_id,
    warehouse_id,
    quantity_on_hand,
    quantity_reserved,
    quantity_available,
    last_updated
  FROM silver.inventory_current;

-- Pattern 3: API-serving Interactive Table
-- Best for: high-concurrency point lookups from applications
CREATE INTERACTIVE TABLE api.order_status
  CLUSTER BY (order_id)
  TARGET_LAG = '60 seconds'
  WAREHOUSE = refresh_wh
  AS
  SELECT order_id, customer_id, status, tracking_number,
         estimated_delivery, last_updated
  FROM silver.orders;

-- Create dedicated Interactive Warehouse for API workload
CREATE INTERACTIVE WAREHOUSE api_iwh
  WAREHOUSE_SIZE = 'SMALL'
  MAX_CLUSTER_COUNT = 3
  MIN_CLUSTER_COUNT = 3  -- Must match MAX for interactive
  MAX_CONCURRENCY_LEVEL = 64
  TABLES (api.order_status, reporting.live_inventory);

ALTER WAREHOUSE api_iwh RESUME;

-- Create separate Interactive Warehouse for dashboard workload
CREATE INTERACTIVE WAREHOUSE dashboard_iwh
  WAREHOUSE_SIZE = 'XSMALL'
  TABLES (reporting.customer_360);

ALTER WAREHOUSE dashboard_iwh RESUME;
```

## Configuration

| Setting | Recommendation | Notes |
|---------|----------------|-------|
| `CLUSTER BY` | Match WHERE clause columns | Most-filtered columns first |
| `TARGET_LAG` | 60s-5min for live data | Minimum 60 seconds |
| `WAREHOUSE_SIZE` | Match working dataset size | See sizing guide in concepts |
| `MAX_CONCURRENCY_LEVEL` | 16-128 for API workloads | Higher = more parallel queries |
| `STATEMENT_TIMEOUT` | 2-5 seconds | Default 5s max |

## Example Usage

```sql
-- Dashboard query (sub-second with interactive warehouse)
USE WAREHOUSE dashboard_iwh;
SELECT segment, region, SUM(total_revenue) AS revenue,
       COUNT(*) AS customer_count
FROM reporting.customer_360
WHERE region = 'US-EAST'
GROUP BY segment, region;

-- API point lookup (millisecond latency)
USE WAREHOUSE api_iwh;
SELECT order_id, status, tracking_number, estimated_delivery
FROM api.order_status
WHERE order_id = 12345678;

-- Monitor interactive table refresh lag
SELECT name, target_lag, actual_lag, last_refresh_time
FROM TABLE(INFORMATION_SCHEMA.INTERACTIVE_TABLE_REFRESH_HISTORY())
ORDER BY last_refresh_time DESC;

-- Monitor warehouse performance
SELECT query_id, total_elapsed_time, bytes_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE warehouse_name = 'API_IWH'
ORDER BY start_time DESC LIMIT 20;
```

## See Also

- [interactive-tables](../concepts/interactive-tables.md)
- [virtual-warehouses](../concepts/virtual-warehouses.md)
- [performance-optimization](../patterns/performance-optimization.md)
