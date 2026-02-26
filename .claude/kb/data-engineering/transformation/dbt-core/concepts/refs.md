# ref() Function

> **Purpose**: Reference other models and build the dependency graph automatically
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The `ref()` function is the most important function in dbt. It references another model,
automatically building the dependency graph (DAG) and interpolating the correct schema.
This enables dbt to run models in the correct order and allows you to change deployment
schemas via configuration without modifying SQL.

## The Pattern

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

with orders as (
    -- ref() builds dependency: stg_orders -> fct_orders
    select * from {{ ref('stg_orders') }}
),

customers as (
    -- Multiple refs in one model
    select * from {{ ref('dim_customers') }}
),

final as (
    select
        o.order_id,
        o.order_date,
        o.amount,
        c.customer_name,
        c.segment
    from orders o
    left join customers c on o.customer_id = c.customer_id
)

select * from final
```

## Quick Reference

| Syntax | Use Case | Example |
|--------|----------|---------|
| `ref('model')` | Same project | `{{ ref('stg_orders') }}` |
| `ref('project', 'model')` | Cross-project | `{{ ref('marketing', 'campaigns') }}` |
| `ref('package', 'model')` | From package | `{{ ref('dbt_utils', 'date_spine') }}` |

## How ref() Works

```text
1. Compile time: {{ ref('stg_orders') }}

2. Resolves to: "analytics"."stg_orders"
   (based on target schema configuration)

3. DAG built: stg_orders --> fct_orders
   (dbt knows to run stg_orders first)
```

## Two-Argument ref()

```sql
-- Recommended when referencing models from other projects/packages
-- More explicit and avoids ambiguity

-- From another dbt project
select * from {{ ref('marketing_project', 'dim_campaigns') }}

-- From an installed package
select * from {{ ref('dbt_utils', 'date_spine') }}
```

## Common Mistakes

### Wrong

```sql
-- Hardcoded reference breaks DAG and schema flexibility
select * from analytics.stg_orders

-- Hardcoded schema prevents environment switching
select * from dev.stg_orders
```

### Correct

```sql
-- ref() handles schema resolution and builds DAG
select * from {{ ref('stg_orders') }}

-- For cross-project, use two-argument form
select * from {{ ref('shared_models', 'dim_date') }}
```

## ref() in Incremental Models

```sql
{{ config(materialized='incremental', unique_key='id') }}

select * from {{ ref('stg_events') }}
{% if is_incremental() %}
    -- {{ this }} refers to the current model's existing table
    where event_time > (select max(event_time) from {{ this }})
{% endif %}
```

## Selector Syntax with ref()

```bash
# Run model and all its upstream dependencies
dbt run --select +fct_orders

# Run model and all downstream dependents
dbt run --select stg_orders+

# Run model with both upstream and downstream
dbt run --select @fct_orders
```

## Related

- [models.md](models.md)
- [sources.md](sources.md)
- [jinja-macros.md](jinja-macros.md)
