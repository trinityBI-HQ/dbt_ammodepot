{% macro convert_tz(source_tz, target_tz, timestamp_expr) %}
    {{ return(adapter.dispatch('convert_tz', 'ammodepot')(source_tz, target_tz, timestamp_expr)) }}
{% endmacro %}

{% macro snowflake__convert_tz(source_tz, target_tz, timestamp_expr) %}
    convert_timezone('{{ source_tz }}', '{{ target_tz }}', {{ timestamp_expr }})
{% endmacro %}

{% macro redshift__convert_tz(source_tz, target_tz, timestamp_expr) %}
    convert_timezone('{{ source_tz }}', '{{ target_tz }}', {{ timestamp_expr }})
{% endmacro %}

{% macro duckdb__convert_tz(source_tz, target_tz, timestamp_expr) %}
    ({{ timestamp_expr }}) AT TIME ZONE '{{ source_tz }}' AT TIME ZONE '{{ target_tz }}'
{% endmacro %}

{% macro default__convert_tz(source_tz, target_tz, timestamp_expr) %}
    convert_timezone('{{ source_tz }}', '{{ target_tz }}', {{ timestamp_expr }})
{% endmacro %}
