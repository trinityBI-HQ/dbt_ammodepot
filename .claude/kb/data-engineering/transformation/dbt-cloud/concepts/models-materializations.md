# Models and Materializations

> **Purpose**: SQL/Python model creation and materialization strategies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Models are SQL or Python files that define data transformations. Materializations determine how models are persisted in the warehouse. dbt ships with five built-in materializations: view, table, incremental, ephemeral, and materialized_view. The microbatch incremental strategy (v1.9+) adds time-series batch processing.

## SQL Model Example

```sql
-- models/staging/stg_orders.sql
{{ config(materialized='view') }}

select
    id as order_id,
    user_id,
    order_date,
    status,
    amount
from {{ source('raw', 'orders') }}
where order_date >= '2024-01-01'
```

## Python Model Example

```python
# models/ml/customer_segments.py
import pandas as pd

def model(dbt, session):
    dbt.config(materialized="table")

    customers_df = dbt.ref("stg_customers").to_pandas()
    # ML logic here
    return customers_df
```

## Materialization Types

| Type | Storage | Rebuild | Use Case |
|------|---------|---------|----------|
| `view` | None | Every query | Light transforms |
| `table` | Full | Complete | Heavy transforms |
| `incremental` | Partial | Delta only | Large datasets |
| `ephemeral` | None | Inlined | CTEs, no storage |
| `materialized_view` | Full | Auto-refresh | Warehouse-managed |
| `microbatch` | Partial | Time batches | Time-series (v1.9+) |

## Configuration Methods

```sql
-- In-model config
{{ config(
    materialized='incremental',
    unique_key='id',
    on_schema_change='append_new_columns'
) }}
```

```yaml
# In dbt_project.yml
models:
  my_project:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

## Microbatch Strategy (v1.9+)

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='created_at',
    begin='2024-01-01',
    batch_size='day'
) }}
select * from {{ ref('stg_events') }}
```

## Common Mistakes

### Wrong

```sql
-- Missing config, defaults to view
select * from {{ ref('stg_orders') }}
```

### Correct

```sql
-- Explicit materialization
{{ config(materialized='table') }}
select * from {{ ref('stg_orders') }}
```

## Related

- [Incremental Models](../patterns/incremental-models.md)
- [sources-seeds](sources-seeds.md)
