{% macro json_extract_text(column, keys) %}
    {{ return(adapter.dispatch('json_extract_text', 'ammodepot')(column, keys)) }}
{% endmacro %}

{% macro snowflake__json_extract_text(column, keys) %}
    try_parse_json({{ column }}){% for key in keys %}:"{{ key }}"{% endfor %}::varchar
{% endmacro %}

{% macro redshift__json_extract_text(column, keys) %}
    json_extract_path_text({{ column }}, {{ keys | map("tojson") | join(", ") }})
{% endmacro %}

{% macro duckdb__json_extract_text(column, keys) %}
    json_extract_string({{ column }}, '${% for key in keys %}.{{ key }}{% endfor %}')
{% endmacro %}

{% macro default__json_extract_text(column, keys) %}
    json_extract_path_text({{ column }}, {{ keys | map("tojson") | join(", ") }})
{% endmacro %}
