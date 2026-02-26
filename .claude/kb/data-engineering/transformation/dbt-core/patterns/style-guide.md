# Style Guide

> **Purpose**: Official SQL, Jinja, and YAML style conventions from dbt best practices
> **Source**: https://docs.getdbt.com/best-practices/how-we-style
> **MCP Validated**: 2026-02-19

## Principles

- **Clarity**: Code should be quickly readable with clear git diffs
- **Consistency**: Unified style across the entire team; use linters to enforce

## SQL Style

### Formatting

- **Line length**: 80 characters max
- **Indentation**: 4 spaces (not tabs)
- **Capitalization**: All lowercase for field names, keywords, functions
- **Aliases**: Always use explicit `as` keyword
- **Commas**: Trailing commas (end of line)
- **Joins**: Always explicit type (`inner join` not `join`); avoid right joins
- **Grouping**: Use `group by 1, 2` (numeric) instead of column names
- **Union**: Prefer `union all` over `union` unless deduplication needed

### Field Naming

| Type | Convention | Example |
|------|-----------|---------|
| Primary key | `<object>_id` | `account_id` |
| Boolean | `is_` or `has_` prefix | `is_fulfilled` |
| Timestamp | `<event>_at` (UTC) | `created_at` |
| Date | `<event>_date` | `created_date` |
| Price/revenue | Decimal currency | `order_total` |
| All fields | `snake_case` | `first_name` |
| Model versions | `_v1`, `_v2` suffix | `customers_v2` |

### Field Ordering

Group and label columns in this order: ids, strings, numerics, booleans, dates, timestamps.

```sql
select
    ---------- ids
    id as order_id,
    store_id as location_id,
    ---------- strings
    status as order_status,
    ---------- numerics
    (order_total / 100.0)::float as order_total,
    ---------- booleans
    is_fulfilled,
    ---------- dates
    date(order_date) as ordered_date,
    ---------- timestamps
    ordered_at
from source
```

### CTE Conventions

```sql
-- 1. Import CTEs first: all ref/source at top, named after source
with orders as (
    select * from {{ ref('stg_ecommerce__orders') }}
),

-- 2. Functional CTEs: one logical task each, descriptive names
orders_with_payments as (
    select
        orders.order_id,
        orders.customer_id,
        payments.amount
    from orders
    inner join payments on orders.order_id = payments.order_id
),

-- 3. Final CTE: select * for easy auditing
final as (
    select * from orders_with_payments
)

select * from final
```

### Join Rules

- Always prefix columns with table/CTE name when joining
- Use descriptive CTE names, not aliases (`customers` not `c`)
- Join conditions: `left_table.id = right_table.id` (left-to-right reading)
- Fields before aggregates/window functions in SELECT

## Jinja Style

```jinja
{# Spaces inside delimiters #}
{{ this }}       {# correct #}
{{this}}         {# wrong #}

{# 4-space indent inside blocks #}
{% macro cents_to_dollars(column_name, precision=2) %}
    round({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}

{# Newlines between logical blocks #}
{% if target.name == 'prod' %}
    {{ config(materialized='table') }}
{% else %}
    {{ config(materialized='view') }}
{% endif %}
```

- Use `{# jinja comments #}` for notes that shouldn't appear in compiled SQL
- Prioritize source readability over compiled output whitespace

## YAML Style

```yaml
# 2-space indentation
# Indent list items
# 80-char max line length
version: 2

models:
  - name: stg_ecommerce__orders
    description: Cleaned orders from ecommerce source
    columns:
      - name: order_id
        description: Primary key
        data_tests:
          - unique
          - not_null

      - name: customer_id
        description: Foreign key to customers
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_ecommerce__customers')
              field: customer_id
```

- Separate list items that are dictionaries with blank lines
- Use explicit list format even for single entries: `['value']`
- Use Prettier or dbt JSON schema for auto-formatting

## Tooling

| Tool | Purpose |
|------|---------|
| SQLFluff | SQL linting and formatting |
| Prettier | YAML formatting |
| dbt JSON schema | YAML validation in IDE |
| sqlfmt | Alternative SQL formatter |

## Model Naming

| Layer | Convention | Example |
|-------|-----------|---------|
| Staging | `stg_[source]__[entity]s` | `stg_stripe__payments` |
| Intermediate | `int_[entity]s_[verb]s` | `int_payments_pivoted_to_orders` |
| Marts | Plain entity name (plural) | `customers`, `orders` |

## See Also

- [project-structure.md](project-structure.md)
- [custom-macros.md](custom-macros.md)
