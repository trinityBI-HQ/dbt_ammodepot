{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'prod' -%}
        {%- if custom_schema_name is none -%}
            {{ target.schema }}
        {%- else -%}
            {{ custom_schema_name | trim }}
        {%- endif -%}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
