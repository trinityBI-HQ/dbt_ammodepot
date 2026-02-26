# Incremental Models Pattern

> **Purpose**: Efficiently process only new or changed data instead of full rebuilds
> **MCP Validated**: 2026-02-19

## When to Use

- Fact tables with millions or billions of rows
- Event/log data that grows continuously
- Transformations taking too long with full table rebuilds
- Source data has reliable timestamp or sequence columns

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
        -- Only process new/updated rows since last run
        -- Add lookback window for late-arriving data
        where updated_at > (
            select coalesce(max(updated_at), '1900-01-01')
            from {{ this }}
        ) - interval '3 hours'
    {% endif %}
),

transformed as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        amount,
        -- Add processing metadata
        updated_at,
        current_timestamp as dbt_updated_at
    from source_data
)

select * from transformed
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `unique_key` | None | Column(s) for merge/upsert |
| `incremental_strategy` | adapter default | merge, delete+insert, append, microbatch (v1.9+) |
| `on_schema_change` | ignore | fail, append_new_columns, sync_all_columns |

## Incremental Strategies

```sql
-- APPEND: Just add new rows (fastest, no deduplication)
{{ config(
    materialized='incremental',
    incremental_strategy='append'
) }}

-- DELETE+INSERT: Delete matching rows, then insert
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='delete+insert'
) }}

-- MERGE: Upsert based on unique_key (most common)
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
) }}

-- MICROBATCH (dbt 1.9+, stable): Time-based batching with auto-backfill
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='order_date',
    begin='2024-01-01',
    batch_size='day',
    lookback=3
) }}
-- No is_incremental() block needed; dbt handles filtering via event_time
```

## Microbatch Deep Dive (v1.9+)

Microbatch processes time-series data in configurable time batches using an
`event_time` column. Failed batches can be retried individually without reprocessing
the entire dataset. No `is_incremental()` block is needed.

```sql
-- models/marts/fct_page_views.sql
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='viewed_at',
    begin='2024-01-01',
    batch_size='day',
    lookback=1
) }}

select
    page_view_id,
    user_id,
    page_url,
    viewed_at,
    session_id
from {{ ref('stg_page_views') }}
```

| Config | Required | Description |
|--------|----------|-------------|
| `event_time` | Yes | Timestamp column for batch boundaries |
| `begin` | Yes | Start date for initial backfill |
| `batch_size` | Yes | hour, day, month, or year |
| `lookback` | No | Number of prior batches to reprocess (default 1) |

## Handling Late-Arriving Data

```sql
{% if is_incremental() %}
    -- Option 1: Lookback window
    where event_time > (select max(event_time) from {{ this }}) - interval '6 hours'

    -- Option 2: Use a watermark with buffer
    where event_time >= '{{ var("incremental_start_date") }}'

    -- Option 3: Sequence-based (Kafka offset, database sequence)
    where kafka_offset > (select coalesce(max(kafka_offset), 0) from {{ this }})
{% endif %}
```

## Compound Unique Keys

```sql
{{ config(
    materialized='incremental',
    unique_key=['order_id', 'line_item_id'],  -- Composite key
    incremental_strategy='merge'
) }}
```

## Testing Incremental Models

```bash
# Always verify model works with full refresh
dbt run --select fct_orders --full-refresh

# Run incrementally
dbt run --select fct_orders

# Compare row counts (should match for idempotent models)
dbt run --select fct_orders --full-refresh && dbt run --select fct_orders
```

## Example Usage

```sql
-- Macro for consistent incremental logic
{% macro incremental_filter(timestamp_column, lookback_hours=3) %}
    {% if is_incremental() %}
        where {{ timestamp_column }} > (
            select coalesce(max({{ timestamp_column }}), '1900-01-01')
            from {{ this }}
        ) - interval '{{ lookback_hours }} hours'
    {% endif %}
{% endmacro %}

-- Usage in model
select * from {{ ref('stg_events') }}
{{ incremental_filter('event_timestamp', 6) }}
```

## See Also

- [materializations.md](../concepts/materializations.md)
- [models.md](../concepts/models.md)
- [testing-strategy.md](testing-strategy.md)
