# Custom Macros Pattern

> **Purpose**: Build reusable macro libraries for DRY SQL and consistent transformations
> **MCP Validated**: 2026-02-19

## When to Use

- Repeating the same SQL logic across multiple models
- Standardizing transformations (date formatting, currency conversion)
- Implementing adapter-specific SQL that works across warehouses
- Creating project-specific utility functions

## Implementation

```sql
-- macros/transformations/currency.sql
{% macro cents_to_dollars(column_name, precision=2) %}
    {#- Convert cents to dollars with rounding -#}
    round(cast({{ column_name }} as numeric) / 100.0, {{ precision }})
{% endmacro %}

{% macro format_currency(column_name, currency_symbol='$') %}
    {#- Format as currency string -#}
    concat('{{ currency_symbol }}', cast({{ column_name }} as varchar))
{% endmacro %}

-- macros/transformations/dates.sql
{% macro fiscal_quarter(date_column, fiscal_year_start_month=7) %}
    {#- Calculate fiscal quarter (default: July start) -#}
    case
        when extract(month from {{ date_column }}) >= {{ fiscal_year_start_month }}
        then ceil((extract(month from {{ date_column }}) - {{ fiscal_year_start_month }} + 1) / 3.0)
        else ceil((extract(month from {{ date_column }}) + 12 - {{ fiscal_year_start_month }} + 1) / 3.0)
    end
{% endmacro %}

{% macro date_trunc_to_week_start(date_column, week_start='monday') %}
    {#- Truncate date to week start (configurable start day) -#}
    {% if week_start == 'sunday' %}
        date_trunc('week', {{ date_column }}) - interval '1 day'
    {% else %}
        date_trunc('week', {{ date_column }})
    {% endif %}
{% endmacro %}
```

## Configuration

| Macro Feature | Syntax | Example |
|---------------|--------|---------|
| Parameters | `{% macro name(param) %}` | `{% macro my_macro(col) %}` |
| Defaults | `param=default` | `precision=2` |
| Doc strings | `{#- comment -#}` | `{#- Converts cents -#}` |
| Return value | Implicit output | Output becomes SQL |

## Adapter-Specific Macros

```sql
-- macros/cross_db/safe_divide.sql
{% macro safe_divide(numerator, denominator, default=0) %}
    {{ adapter.dispatch('safe_divide')(numerator, denominator, default) }}
{% endmacro %}

{% macro default__safe_divide(numerator, denominator, default) %}
    case
        when {{ denominator }} = 0 then {{ default }}
        else {{ numerator }} / {{ denominator }}
    end
{% endmacro %}

{% macro snowflake__safe_divide(numerator, denominator, default) %}
    coalesce(div0null({{ numerator }}, {{ denominator }}), {{ default }})
{% endmacro %}

{% macro bigquery__safe_divide(numerator, denominator, default) %}
    coalesce(safe_divide({{ numerator }}, {{ denominator }}), {{ default }})
{% endmacro %}
```

## Generating SQL Dynamically

```sql
-- macros/generators/pivot.sql
{% macro pivot_values(column_name, values_list, agg_function='sum', value_column=None) %}
    {% for value in values_list %}
        {{ agg_function }}(
            case when {{ column_name }} = '{{ value }}'
            then {% if value_column %}{{ value_column }}{% else %}1{% endif %}
            end
        ) as {{ value | lower | replace(' ', '_') }}
        {% if not loop.last %},{% endif %}
    {% endfor %}
{% endmacro %}

-- Usage in model
select
    customer_id,
    {{ pivot_values('status', ['Pending', 'Shipped', 'Delivered'], 'count') }}
from {{ ref('stg_orders') }}
group by customer_id
```

## Union Tables Macro

```sql
-- macros/generators/union_tables.sql
{% macro union_tables(table_names, include_source_column=true) %}
    {% for table_name in table_names %}
        select
            {% if include_source_column %}
            '{{ table_name }}' as _source_table,
            {% endif %}
            *
        from {{ ref(table_name) }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
{% endmacro %}

-- Usage
{{ union_tables(['stg_orders_2022', 'stg_orders_2023', 'stg_orders_2024']) }}
```

## Incremental Filter Macro

```sql
-- macros/incremental_helpers.sql
{% macro incremental_filter(timestamp_column, lookback_hours=3) %}
    {% if is_incremental() %}
        where {{ timestamp_column }} > (
            select coalesce(max({{ timestamp_column }}), '1900-01-01'::timestamp)
            from {{ this }}
        ) - interval '{{ lookback_hours }} hours'
    {% endif %}
{% endmacro %}

-- Usage in incremental model
select * from {{ ref('stg_events') }}
{{ incremental_filter('event_timestamp', 6) }}
```

## Example Usage

```sql
-- models/marts/fct_orders.sql
select
    order_id,
    customer_id,
    order_date,
    {{ cents_to_dollars('amount_cents') }} as amount,
    {{ cents_to_dollars('tax_cents', 4) }} as tax,
    {{ fiscal_quarter('order_date') }} as fiscal_quarter,
    {{ safe_divide('amount_cents', 'quantity') }} as unit_price
from {{ ref('stg_orders') }}
```

## See Also

- [jinja-macros.md](../concepts/jinja-macros.md)
- [incremental-models.md](incremental-models.md)
- [testing-strategy.md](testing-strategy.md)
