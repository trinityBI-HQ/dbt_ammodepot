{% macro json_extract_text(column, keys) %}
    {#-
    Portable JSON text extraction macro.
    Extracts a nested value from a JSON string column and returns it as varchar.

    Usage:
        {{ json_extract_text('a.custom_fields', ['Magento Order Identity 1']) }}
        {{ json_extract_text('z.custom_fields', ['25', 'value']) }}

    On Snowflake:  try_parse_json(column):"key1":"key2"::varchar
    On Redshift:   json_extract_path_text(column, 'key1', 'key2')
    -#}
    {%- if target.type == 'snowflake' -%}
        try_parse_json({{ column }}){% for key in keys %}:"{{ key }}"{% endfor %}::varchar
    {%- elif target.type == 'redshift' -%}
        json_extract_path_text({{ column }}, {{ keys | map("tojson") | join(", ") }})
    {%- else -%}
        json_extract_path_text({{ column }}, {{ keys | map("tojson") | join(", ") }})
    {%- endif -%}
{% endmacro %}
