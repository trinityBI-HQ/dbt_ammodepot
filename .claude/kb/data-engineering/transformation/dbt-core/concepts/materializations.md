# Materializations

> **Purpose**: Define how dbt models are persisted in the data warehouse
> **Confidence**: 0.95
> **Source**: https://docs.getdbt.com/best-practices/materializations
> **MCP Validated**: 2026-02-19

## Overview

Materializations determine how dbt builds models in your data warehouse. The core
materializations are view (default), table, incremental, and ephemeral. Since v1.9,
the microbatch incremental strategy adds time-series batching. Choosing the right
materialization impacts query performance, storage costs, and build times.

## The Pattern

```sql
-- View: lightweight, always current
{{ config(materialized='view') }}
select * from {{ ref('stg_orders') }}

-- Table: full rebuild, fast queries
{{ config(materialized='table') }}
select * from {{ ref('stg_orders') }}

-- Incremental: append/merge new rows only
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}
select * from {{ ref('stg_orders') }}
{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}

-- Ephemeral: CTE, no warehouse object
{{ config(materialized='ephemeral') }}
select * from {{ ref('stg_orders') }}
```

## Quick Reference

| Materialization | Creates Object | Build Time | Query Time | Use Case |
|-----------------|----------------|------------|------------|----------|
| `view` | View | Fast | Slow | Dev, small data |
| `table` | Table | Slow | Fast | Dimensions, aggregates |
| `incremental` | Table | Fast* | Fast | Large fact tables |
| `microbatch` | Table | Fast* | Fast | Time-series data (v1.9+) |
| `ephemeral` | None (CTE) | N/A | Varies | Reusable logic |

*After initial full build

## Escalation Strategy (Official Best Practice)

Start simple and escalate only when needed:

```text
1. VIEW → always current, no storage cost
   ↓ query too slow for end users
2. TABLE → fast queries, full rebuild each run
   ↓ build time too long in dbt jobs
3. INCREMENTAL → layer data as it arrives
     ↓ time-series data needs batch processing
4. MICROBATCH → process in time-based batches (v1.9+)
```

## When to Use Each

```text
view
├── Good: Development, staging layer, <100K rows
├── Good: Data must always be current
└── Bad: Large tables, frequently queried

table
├── Good: Dimensions (<1M rows), marts
├── Good: Heavily queried models
└── Bad: Fact tables with billions of rows

incremental
├── Good: Fact tables, event data, logs
├── Good: Tables > 1M rows
└── Bad: Complex logic that must see all data

microbatch (v1.9+)
├── Good: Time-series data with event_time column
├── Good: Auto-backfill and batch retry on failure
└── Bad: Data without reliable time-based ordering

ephemeral
├── Good: Intermediate layer (default)
├── Good: Avoid cluttering warehouse
└── Bad: Models queried directly by BI tools
```

## Common Mistakes

### Wrong

```sql
-- Using view for a large, frequently queried fact table
{{ config(materialized='view') }}
select * from {{ source('raw', 'events') }}  -- 1B rows!
```

### Correct

```sql
-- Use incremental for large fact tables
{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='merge'
) }}
select * from {{ source('raw', 'events') }}
{% if is_incremental() %}
where event_timestamp > (select max(event_timestamp) from {{ this }})
{% endif %}
```

## Project-Level Configuration

```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +materialized: view      # All staging models are views
    intermediate:
      +materialized: ephemeral # Intermediate as CTEs
    marts:
      +materialized: table     # Marts are tables
      facts:
        +materialized: incremental  # Fact tables incremental
```

## Full Refresh

```bash
# Rebuild incremental/microbatch model from scratch
# Use when: schema changes, logic changes, or data quality issues
dbt run --select fct_orders --full-refresh
```

## Related

- [models.md](models.md)
- [incremental-models.md](../patterns/incremental-models.md)
- [project-structure.md](../patterns/project-structure.md)
