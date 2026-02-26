# Incremental Models Pattern

> **Purpose**: Efficiently process large datasets by only transforming new or changed data
> **MCP Validated**: 2026-02-19

## When to Use

- Large fact tables with millions of rows
- Append-only or slowly changing source data
- Need to reduce build times from hours to minutes
- Data has reliable timestamp or unique key for change detection

## Implementation

```sql
-- models/marts/fct_orders.sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='append_new_columns'
    )
}}

with source_data as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        amount,
        updated_at
    from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    -- Only process new/updated records
    where updated_at > (select max(updated_at) from {{ this }})
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id']) }} as order_key,
    order_id,
    customer_id,
    order_date,
    status,
    amount,
    updated_at,
    current_timestamp as dbt_loaded_at
from source_data
```

## Incremental Strategies

| Strategy | Platform | Behavior |
|----------|----------|----------|
| `append` | All | Insert only, no deduplication |
| `merge` | BigQuery, Snowflake, Databricks | Upsert based on unique_key |
| `delete+insert` | All | Delete matching rows, then insert |
| `microbatch` | All (v1.9+) | Process in time-based batches |

## Microbatch Strategy (v1.9+, stable)

Microbatch processes time-series data in configurable batches using an `event_time`
column. Failed batches can be retried individually. No `is_incremental()` block needed.

```sql
{{
    config(
        materialized='incremental',
        incremental_strategy='microbatch',
        event_time='event_timestamp',
        begin='2024-01-01',
        batch_size='day',
        lookback=1
    )
}}

select
    event_id,
    event_timestamp,
    event_data
from {{ ref('stg_events') }}
```

| Config | Required | Description |
|--------|----------|-------------|
| `event_time` | Yes | Timestamp column for batch boundaries |
| `begin` | Yes | Start date for initial backfill |
| `batch_size` | Yes | hour, day, month, or year |
| `lookback` | No | Prior batches to reprocess (default 1) |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `unique_key` | None | Column(s) for merge matching |
| `incremental_strategy` | Platform default | merge, append, delete+insert |
| `on_schema_change` | ignore | sync_all_columns, append_new_columns, fail |

## Full Refresh

```bash
# Rebuild entire table when needed
dbt run --select fct_orders --full-refresh

# Or configure in model
{{ config(full_refresh=var('full_refresh', false)) }}
```

## Common Patterns

```sql
-- Multiple unique keys
{{ config(unique_key=['order_id', 'line_item_id']) }}

-- Late-arriving data handling
{% if is_incremental() %}
where updated_at > (select max(updated_at) - interval '3 days' from {{ this }})
{% endif %}
```

## Example Usage

```bash
# Regular incremental run
dbt run --select fct_orders

# Full refresh for schema changes
dbt run --select fct_orders --full-refresh
```

## See Also

- [models-materializations](../concepts/models-materializations.md)
- [snapshots](../concepts/snapshots.md)
