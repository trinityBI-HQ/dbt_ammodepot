# Models

> **Purpose**: SQL SELECT statements that define data transformations in dbt
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Models are the core building blocks of dbt. Each model is a SQL SELECT statement stored
in a `.sql` file that defines a transformation. dbt handles creating the target object
(view, table, etc.) in your data warehouse. Models reference each other using `ref()`,
which builds the dependency graph (DAG) automatically. As of v1.11, dbt also supports
User-Defined Functions (UDFs) as a new `function()` resource type.

## The Pattern

```sql
-- models/marts/orders/fct_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    schema='marts'
) }}

with source_orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

aggregated as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        sum(oi.quantity * oi.unit_price) as order_total,
        count(oi.item_id) as item_count
    from source_orders o
    left join order_items oi on o.order_id = oi.order_id
    group by 1, 2, 3, 4
)

select * from aggregated
{% if is_incremental() %}
where order_date > (select max(order_date) from {{ this }})
{% endif %}
```

## Quick Reference

| Config | Purpose | Values |
|--------|---------|--------|
| `materialized` | How to build | view, table, incremental, ephemeral, microbatch |
| `schema` | Target schema | string |
| `alias` | Override table name | string |
| `tags` | Organize models | list of strings |
| `unique_key` | For incremental merge | column or list |

## Model Layers

```text
models/
├── staging/          # stg_ prefix, 1:1 with sources
│   └── stg_orders.sql
├── intermediate/     # int_ prefix, reusable logic
│   └── int_orders_pivoted.sql
└── marts/            # fct_/dim_ prefix, business entities
    ├── fct_orders.sql
    └── dim_customers.sql
```

## Common Mistakes

### Wrong

```sql
-- Hardcoded table reference breaks DAG
select * from raw.orders
where order_date > '2024-01-01'
```

### Correct

```sql
-- ref() builds dependency and handles schema
select * from {{ ref('stg_orders') }}
where order_date > '{{ var("start_date") }}'
```

## Model Configuration

```sql
-- In-file config block (highest precedence)
{{ config(
    materialized='table',
    schema='analytics',
    tags=['daily', 'core']
) }}

-- Or in dbt_project.yml (project-wide defaults)
-- models:
--   my_project:
--     marts:
--       +materialized: table
--       +schema: analytics
```

## User-Defined Functions (v1.11)

```sql
-- functions/my_udf.sql
{{ config(schema='udfs') }}

create or replace function {{ this }}(input_val string)
returns string
language sql
as $$
    upper(trim(input_val))
$$;
```

UDFs live in the `functions/` directory and use the `function()` resource type. They are
deployed to the warehouse and can be referenced by models.

## Related

- [materializations.md](materializations.md)
- [refs.md](refs.md)
- [project-structure.md](../patterns/project-structure.md)
