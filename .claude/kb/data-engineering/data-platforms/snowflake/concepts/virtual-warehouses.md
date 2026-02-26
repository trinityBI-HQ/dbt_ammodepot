# Virtual Warehouses

> **Purpose**: Compute clusters that execute SQL queries independently from storage
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A virtual warehouse is a cluster of compute resources in Snowflake. Warehouses process SQL statements and Snowpark operations. They scale independently from storage, allowing you to pay only for compute when queries run. Warehouses can be resized, suspended, and resumed dynamically.

## The Pattern

```sql
-- Create a warehouse with auto-suspend
CREATE WAREHOUSE analytics_wh
  WITH WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 300          -- Suspend after 5 minutes idle
  AUTO_RESUME = TRUE          -- Resume on query submission
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3       -- Multi-cluster scaling (Enterprise+)
  SCALING_POLICY = 'STANDARD';

-- Resize dynamically
ALTER WAREHOUSE analytics_wh SET WAREHOUSE_SIZE = 'LARGE';

-- Suspend to stop billing
ALTER WAREHOUSE analytics_wh SUSPEND;

-- Use specific warehouse for a session
USE WAREHOUSE analytics_wh;
```

## Quick Reference

| Size | Credits/Hr | Nodes | Use Case |
|------|------------|-------|----------|
| X-Small | 1 | 1 | Dev, light queries |
| Small | 2 | 2 | Testing, small data |
| Medium | 4 | 4 | Standard workloads |
| Large | 8 | 8 | Heavy transforms |
| X-Large | 16 | 16 | Large scans |

## Common Mistakes

### Wrong

```sql
-- Warehouse too large for workload, wastes credits
CREATE WAREHOUSE dev_wh WITH WAREHOUSE_SIZE = 'X-LARGE';

-- No auto-suspend, keeps billing even when idle
CREATE WAREHOUSE etl_wh WITH AUTO_SUSPEND = 0;
```

### Correct

```sql
-- Right-sized with auto-suspend
CREATE WAREHOUSE dev_wh
  WITH WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- Dedicated ETL warehouse with appropriate sizing
CREATE WAREHOUSE etl_wh
  WITH WAREHOUSE_SIZE = 'LARGE'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE;
```

## Related

- [databases-schemas](../concepts/databases-schemas.md)
- [performance-optimization](../patterns/performance-optimization.md)
