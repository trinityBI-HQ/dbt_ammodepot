# Style Guide

> **Purpose**: Official SQL, Jinja, and YAML style conventions from dbt best practices
> **Source**: https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql
> **MCP Validated**: 2026-03-13

## Principles

- **Clarity**: Code should be quickly readable with clear git diffs
- **Consistency**: Unified style across the entire team; use linters to enforce

## SQL Style

### Column Selection

- **No `SELECT *` in models** — always use explicit column lists
- Applies to ALL layers (Bronze, Silver, Gold) and ALL CTEs including import CTEs
- The only acceptable `SELECT *` is `select * from final` as the last statement (where columns are already explicitly listed in the final CTE)
- Explicit columns prevent silent schema drift, enable column-level lineage, and reduce compute costs

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

### Fields, Aggregations, and Grouping

- Place fields before aggregates and window functions in SELECT
- Aggregate early on the smallest dataset before joining to improve performance
- Prefer `group by 1, 2` (numeric) over column names

### Import CTE Conventions

- Place ALL `ref()` and `source()` statements in CTEs at the top of the file
- Name import CTEs after the table they reference
- Select only columns needed downstream (explicit lists, never `SELECT *`)
- Do NOT select columns that are only used in `WHERE`, `ON`, or `HAVING` — they don't need to be in `SELECT`
- Filter with `where` clauses in import CTEs to minimize scanned data

```sql
-- region is used in WHERE but not selected (not needed downstream)
with orders as (
    select
        order_id,
        customer_id,
        order_total,
        order_date
    from {{ ref('stg_ecommerce__orders') }}
    where region = 'US'
),
```

### Functional CTE Conventions

- Where performance permits, CTEs should perform a single, logical unit of work
- CTE names should be as verbose as needed to convey what they do (e.g., `events_joined_to_users`)
- If a CTE is duplicated across models, extract into a separate intermediate model
- **The last line of a model should be `select * from final`** — this makes it easy to materialize and audit the output from different steps in the model as you're developing it. You just change the CTE referenced in the select statement to see the output from that step

### Join Rules

- Always prefix columns with table/CTE name when joining
- Use full descriptive CTE names, not aliases (`customers` not `c`)
- Join conditions: `left_table.id = right_table.id` (left-to-right reading)
- Explicit join types always (`inner join` not `join`); avoid `right join`
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
