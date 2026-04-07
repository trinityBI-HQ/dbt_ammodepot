{#
    Refresh all UNMANAGED Iceberg tables in AD_ANALYTICS.LAKEHOUSE_LANDING.

    Wired to on-run-start in dbt_project.yml so every dbt build picks up
    new Airbyte writes before Bronze sources are read. Without this, the
    Iceberg tables serve a stale catalog snapshot and dbt builds against
    frozen data.

    Behavior:
    - Discovers tables dynamically via SHOW ICEBERG TABLES (auto-handles
      new streams added by Airbyte)
    - Only runs on the prod target — dev runs build into dbt_dev and
      should not touch the production landing schema
    - Fails fast if any single REFRESH errors out: building from stale
      data and shipping wrong numbers to Power BI is worse than a build
      failure that pages someone
#}
{% macro refresh_lakehouse_landing() %}

    {# on-run-start hooks are evaluated during parse — guard run_query #}
    {% if not execute %}
        {{ return('select 1 as skipped_during_parse') }}
    {% endif %}

    {% if target.name != 'prod' %}
        {% do log(
            "refresh_lakehouse_landing: skipped (target=" ~ target.name ~ ")",
            info=true
        ) %}
        {{ return('select 1 as skipped_non_prod') }}
    {% endif %}

    {% set discovery_query %}
        show iceberg tables in schema ad_analytics.lakehouse_landing
    {% endset %}

    {% set results = run_query(discovery_query) %}

    {% if results is none or results.rows | length == 0 %}
        {% do log(
            "refresh_lakehouse_landing: no iceberg tables found — skipping",
            info=true
        ) %}
        {{ return('select 1 as no_tables_found') }}
    {% endif %}

    {% set table_count = results.rows | length %}
    {% do log(
        "refresh_lakehouse_landing: refreshing " ~ table_count ~ " iceberg tables",
        info=true
    ) %}

    {% for row in results.rows %}
        {# 'name' is column index 1 in SHOW ICEBERG TABLES output #}
        {% set table_name = row[1] %}
        {% set refresh_sql %}
            alter iceberg table ad_analytics.lakehouse_landing.{{ table_name }} refresh
        {% endset %}
        {% do run_query(refresh_sql) %}
    {% endfor %}

    {% do log(
        "refresh_lakehouse_landing: refreshed " ~ table_count ~ " iceberg tables",
        info=true
    ) %}

    {# All work happened in the run_query() loop above. The returned SQL is
       a no-op so dbt's on-run-start hook executor has something to run. #}
    {{ return('select ' ~ table_count ~ ' as iceberg_tables_refreshed') }}

{% endmacro %}
