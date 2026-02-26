# Warehouse Cost Management

> **Purpose**: Optimize costs for Snowflake, BigQuery, and Databricks SQL warehouses
> **MCP Validated**: 2026-02-19

## When to Use

- Snowflake credit consumption exceeds budget
- BigQuery scan costs are unpredictable
- Warehouse sizing has never been reviewed
- Ad-hoc queries consume more credits than ETL workloads
- Teams share warehouses without cost visibility

## Snowflake Credit Optimization

### Warehouse Sizing Strategy

Start small and scale up only when query performance is unacceptable. Larger warehouses run queries faster but consume more credits per second.

```sql
-- Analyze current warehouse utilization
SELECT
    warehouse_name,
    warehouse_size,
    AVG(avg_running) AS avg_concurrent_queries,
    AVG(avg_queued_load) AS avg_queued,
    SUM(credits_used) AS total_credits_30d
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, warehouse_size
ORDER BY total_credits_30d DESC;
```

**Sizing decision matrix:**

| Avg Query Time | Queue Depth | Action |
|---------------|-------------|--------|
| < 10s | 0 | Consider downsizing |
| 10-60s | 0-1 | Optimal |
| 60-300s | 0 | Acceptable for ETL |
| Any | > 2 consistently | Scale up or split workload |

### Auto-Suspend Configuration

```sql
-- Set auto-suspend to 60 seconds (minimum recommended)
ALTER WAREHOUSE DE_ETL_MEDIUM SET
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- For BI/ad-hoc warehouses with cache sensitivity
ALTER WAREHOUSE ANALYTICS_ADHOC SET
    AUTO_SUSPEND = 300  -- 5 min to preserve cache
    AUTO_RESUME = TRUE;
```

**Key insight:** Because Snowflake bills per-second with a 60-second minimum, setting auto-suspend to 30 seconds can cause double billing if a new query arrives shortly after suspension.

### Warehouse Segmentation

```sql
-- Separate warehouses by workload type
CREATE WAREHOUSE DE_ETL_MEDIUM      -- Scheduled ETL jobs
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60;

CREATE WAREHOUSE ANALYTICS_SMALL    -- BI dashboard refreshes
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300;

CREATE WAREHOUSE ADHOC_XSMALL       -- Ad-hoc analyst queries
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60;

CREATE WAREHOUSE DE_HEAVY_LARGE     -- Large backfills (temporary)
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 60;
```

### Resource Monitors

```sql
CREATE RESOURCE MONITOR etl_monitor
    WITH CREDIT_QUOTA = 3000
    FREQUENCY = MONTHLY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE DE_ETL_MEDIUM SET RESOURCE_MONITOR = etl_monitor;
```

### Query Optimization for Credits

```sql
-- Identify expensive queries
SELECT
    query_id,
    user_name,
    warehouse_name,
    execution_time / 1000 AS execution_seconds,
    bytes_scanned / POWER(1024, 3) AS gb_scanned,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 1) AS pct_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
    AND execution_time > 60000  -- > 60 seconds
ORDER BY execution_time DESC
LIMIT 20;
```

**Optimization checklist:**
- Queries scanning > 50% of partitions need better clustering
- Convert `SELECT *` to specific columns
- Add clustering keys on commonly filtered columns
- Use materialized views for repeated expensive queries

## BigQuery Cost Optimization

### Partitioning and Clustering

```sql
-- Partition by date, cluster by common filter columns
CREATE TABLE `project.dataset.events`
PARTITION BY DATE(event_timestamp)
CLUSTER BY user_id, event_type
AS SELECT * FROM `project.dataset.raw_events`;
```

**Impact:** Partitioning + clustering can reduce bytes scanned by 80-95%.

### Edition Selection

| Edition | Slot Price | Best For |
|---------|-----------|----------|
| On-Demand | $6.25/TB scanned | < 1 TB/day scanned |
| Standard | $0.04/slot-hour | Moderate, predictable workloads |
| Enterprise | $0.06/slot-hour | Cross-region, governance needs |

**Decision rule:** If monthly scan volume > 200 TB, evaluate editions vs on-demand.

### Query Cost Controls

```sql
-- Set maximum bytes billed per query (safety guardrail)
-- Fails queries that would scan > 10 GB
SELECT * FROM `project.dataset.large_table`
WHERE date = '2025-01-15'
OPTIONS(maximum_bytes_billed = 10737418240);  -- 10 GB
```

### BigQuery Slots Monitoring

```sql
-- Monitor slot utilization (INFORMATION_SCHEMA)
SELECT
    period_start,
    period_slot_ms,
    period_shuffle_ram_usage_ratio
FROM `project.region-us`.INFORMATION_SCHEMA.JOBS_TIMELINE
WHERE period_start > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY period_start;
```

## Databricks SQL Warehouse

### Serverless vs Classic

| Type | DBU Rate | Start Time | Best For |
|------|----------|------------|----------|
| Serverless | Higher per DBU | Instant | Bursty, interactive |
| Classic (Pro) | Lower per DBU | 2-5 min | Steady, scheduled |

### Configuration

```sql
-- Databricks SQL warehouse sizing
-- Start with 2X-Small, scale based on queue depth
-- Set auto-stop to 10 minutes for scheduled workloads
-- Set scaling min=1, max=3 for controlled autoscaling
```

## Optimization Summary

| Platform | Top 3 Actions | Expected Savings |
|----------|--------------|------------------|
| Snowflake | Auto-suspend 60s, right-size, segment | 30-60% |
| BigQuery | Partition+cluster, edition review, limits | 40-70% |
| Databricks SQL | Serverless for bursty, right-size, auto-stop | 20-40% |

## See Also

- [Data Pipeline Optimization](data-pipeline-optimization.md) -- Compute cluster optimization
- [Cloud Billing](../concepts/cloud-billing.md) -- Understanding pricing models
- [Unit Economics](../concepts/unit-economics.md) -- Measuring cost per query
