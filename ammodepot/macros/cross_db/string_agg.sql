{% macro string_agg(column, separator, order_by_column) %}
    {{ return(adapter.dispatch('string_agg', 'ammodepot')(column, separator, order_by_column)) }}
{% endmacro %}

{% macro snowflake__string_agg(column, separator, order_by_column) %}
    listagg({{ column }}, '{{ separator }}') within group (order by {{ order_by_column }})
{% endmacro %}

{% macro redshift__string_agg(column, separator, order_by_column) %}
    listagg({{ column }}, '{{ separator }}') within group (order by {{ order_by_column }})
{% endmacro %}

{% macro duckdb__string_agg(column, separator, order_by_column) %}
    string_agg({{ column }}, '{{ separator }}' order by {{ order_by_column }})
{% endmacro %}

{% macro default__string_agg(column, separator, order_by_column) %}
    listagg({{ column }}, '{{ separator }}') within group (order by {{ order_by_column }})
{% endmacro %}
