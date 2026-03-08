{% macro format_timestamp(timestamp_expr, format_str) %}
    {{ return(adapter.dispatch('format_timestamp', 'ammodepot')(timestamp_expr, format_str)) }}
{% endmacro %}

{% macro snowflake__format_timestamp(timestamp_expr, format_str) %}
    to_char({{ timestamp_expr }}, '{{ format_str }}')
{% endmacro %}

{% macro redshift__format_timestamp(timestamp_expr, format_str) %}
    to_char({{ timestamp_expr }}, '{{ format_str }}')
{% endmacro %}

{%- macro duckdb__format_timestamp(timestamp_expr, format_str) -%}
    {#- Map common Snowflake/Redshift format tokens to strftime equivalents -#}
    {%- set duckdb_fmt = format_str
        | replace("HH24", "%H")
        | replace("MI", "%M")
        | replace("SS", "%S")
        | replace("YYYY", "%Y")
        | replace("MM", "%m")
        | replace("DD", "%d")
    -%}
    strftime({{ timestamp_expr }}, '{{ duckdb_fmt }}')
{%- endmacro %}

{% macro default__format_timestamp(timestamp_expr, format_str) %}
    to_char({{ timestamp_expr }}, '{{ format_str }}')
{% endmacro %}
