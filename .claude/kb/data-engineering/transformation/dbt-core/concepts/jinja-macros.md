# Jinja and Macros

> **Purpose**: Templating language for dynamic SQL generation and reusable code
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Jinja is a templating language embedded in dbt that enables dynamic SQL generation.
Macros are reusable Jinja templates defined in `.sql` files within the `macros/`
directory. Together, they allow DRY (Don't Repeat Yourself) SQL, conditional logic,
and programmatic model generation.

## The Pattern

```sql
-- macros/generate_schema_name.sql
{% macro cents_to_dollars(column_name, precision=2) %}
    round({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}

-- Usage in a model
select
    order_id,
    {{ cents_to_dollars('amount_cents') }} as amount_dollars,
    {{ cents_to_dollars('tax_cents', 4) }} as tax_dollars
from {{ ref('stg_orders') }}
```

## Quick Reference

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{ }}` | Expression/output | `{{ ref('model') }}` |
| `{% %}` | Statement/logic | `{% if condition %}` |
| `{# #}` | Comment (not parsed) | `{# TODO: fix this #}` |

## Core Jinja Functions

```sql
-- Variables
{% set my_list = ['a', 'b', 'c'] %}
{% set my_dict = {'key': 'value'} %}

-- Conditionals
{% if target.name == 'prod' %}
    select * from prod_table
{% else %}
    select * from {{ ref('dev_sample') }}
{% endif %}

-- Loops
select
{% for col in ['id', 'name', 'status'] %}
    {{ col }}{% if not loop.last %},{% endif %}
{% endfor %}
from {{ ref('my_model') }}

-- Filters
{{ 'hello world' | upper }}  -- HELLO WORLD
{{ my_list | join(', ') }}   -- a, b, c
```

## dbt-Specific Functions

```sql
-- Reference another model
{{ ref('stg_orders') }}

-- Reference a source table
{{ source('raw', 'orders') }}

-- Get project variable
{{ var('start_date', '2020-01-01') }}

-- Environment variable
{{ env_var('DBT_TARGET', 'dev') }}

-- Current model's table (for incremental)
{{ this }}

-- Target information
{{ target.name }}    -- dev, prod, etc.
{{ target.schema }}  -- target schema
```

## Common Mistakes

### Wrong

```sql
-- Jinja comment hides ref from parser (breaks DAG)
{# select * from {{ ref('orders') }} #}

-- Missing macro endmacro
{% macro my_macro() %}
  select 1
-- forgot {% endmacro %}
```

### Correct

```sql
-- SQL comment preserves ref parsing
-- select * from {{ ref('orders') }}

-- Complete macro definition
{% macro my_macro() %}
  select 1
{% endmacro %}
```

## YAML Anchors (v1.10+)

```yaml
# dbt_project.yml or schema.yml
anchors:
  - &common_tests
    data_tests:
      - unique
      - not_null

models:
  - name: stg_orders
    columns:
      - name: order_id
        <<: *common_tests
      - name: customer_id
        <<: *common_tests
```

The `anchors:` top-level key (v1.10+) provides cleaner YAML reuse without workarounds.

## Related

- [custom-macros.md](../patterns/custom-macros.md)
- [models.md](models.md)
- [refs.md](refs.md)
