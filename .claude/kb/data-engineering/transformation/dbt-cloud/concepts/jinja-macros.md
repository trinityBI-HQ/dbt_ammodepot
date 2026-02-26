# Jinja and Macros

> **Purpose**: Templating for dynamic SQL and reusable code
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

dbt combines SQL with Jinja, a templating language that enables dynamic SQL generation. Macros are reusable Jinja templates that accept arguments and generate SQL at compile time. They reduce redundancy and enforce consistency across your project.

## Jinja Syntax

```sql
-- Expressions: output values
{{ ref('stg_orders') }}
{{ var('start_date') }}

-- Statements: control flow
{% if target.name == 'prod' %}
    where created_at >= '2024-01-01'
{% endif %}

-- Comments: ignored by dbt
{# This is a comment #}
```

## Macro Definition

```sql
-- macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name }}
    {%- endif -%}
{% endmacro %}
```

## Using Macros

```sql
-- models/staging/stg_orders.sql
{% set payment_methods = ['credit_card', 'bank_transfer', 'paypal'] %}

select
    order_id,
    {% for method in payment_methods %}
    sum(case when payment_method = '{{ method }}' then amount end) as {{ method }}_amount
    {%- if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('raw_payments') }}
group by 1
```

## Variables

```yaml
# dbt_project.yml
vars:
  start_date: '2024-01-01'
  default_country: 'US'
```

```sql
-- Using variables
where created_at >= '{{ var("start_date") }}'
```

## Common Packages

| Package | Purpose |
|---------|---------|
| `dbt-utils` | Generic macros (surrogate_key, pivot) |
| `dbt-expectations` | Great Expectations-style tests |
| `dbt-audit-helper` | Audit and compare models |

## Common Mistakes

### Wrong

```sql
-- Complex logic inline
{% if condition1 and condition2 or (condition3 and not condition4) %}
```

### Correct

```sql
-- Extract to macro for readability
{% if should_filter_data(target.name) %}
```

## Related

- [models-materializations](models-materializations.md)
- [Testing Strategy](../patterns/testing-strategy.md)
