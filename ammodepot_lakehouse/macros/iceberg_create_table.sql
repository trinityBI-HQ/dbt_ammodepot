{% macro duckdb__create_table_as(temporary, relation, compiled_code, language='sql') -%}
  {%- if language == 'sql' -%}
    {% set contract_config = config.get('contract') %}
    {% if contract_config.enforced %}
      {{ get_assert_columns_equivalent(compiled_code) }}
    {% endif %}
    {%- set sql_header = config.get('sql_header', none) -%}

    {{ sql_header if sql_header is not none }}

    {#-- Iceberg location injection for Glue catalog tables --#}
    {#-- Auto-generate location when writing to glue database --#}
    {%- set iceberg_location = config.get('iceberg_location', none) -%}
    {%- if iceberg_location is none and relation.database == 'glue' -%}
      {%- set iceberg_location = var('s3_iceberg_prefix') ~ '/' ~ relation.schema ~ '.db/' ~ relation.identifier -%}
    {%- endif -%}

    create {% if temporary: -%}temporary{%- endif %} table
      {{ relation.include(database=(not temporary), schema=(not temporary)) }}
    {%- if iceberg_location %}
    with ('location' = '{{ iceberg_location }}')
    {%- endif %}
  {% if contract_config.enforced and not temporary %}
    {#-- DuckDB doesnt support constraints on temp tables --#}
    {{ get_table_columns_and_constraints() }} ;
    insert into {{ relation }} {{ get_column_names() }} (
      {{ compiled_code }}
    );
  {%- else %}
    as (
      {{ compiled_code }}
    );
  {%- endif %}
  {%- elif language == 'python' -%}
    {{ py_write_table(temporary, relation, compiled_code) }}
  {%- else -%}
      {% do exceptions.raise_compiler_error("duckdb__create_table_as macro didn't get supported language, it got %s" % language) %}
  {%- endif -%}
{%- endmacro %}
