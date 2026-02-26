# Data Sources

> **Purpose**: Configuring Soda connections to databases and warehouses
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A data source is a connection to a database or warehouse that Soda scans for data quality. Configuration is stored in `configuration.yml` using data-source-specific parameters. Each data source requires its own pip package.

## Supported Data Sources

| Data Source | Package (v4) | Package (v3 legacy) |
|-------------|-------------|---------------------|
| PostgreSQL | `soda-postgres` | `soda-core-postgres` |
| Snowflake | `soda-snowflake` | `soda-core-snowflake` |
| BigQuery | `soda-bigquery` | `soda-core-bigquery` |
| Databricks | `soda-databricks` | `soda-core-spark[databricks]` |
| Redshift | `soda-redshift` | `soda-core-redshift` |
| Spark | `soda-spark` | `soda-core-spark` |
| DuckDB | `soda-duckdb` | `soda-core-duckdb` |
| MySQL | `soda-mysql` | `soda-core-mysql` |
| MS SQL Server | `soda-sqlserver` | `soda-core-sqlserver` |
| Trino | `soda-trino` | `soda-core-trino` |

## Configuration Examples

### PostgreSQL

```yaml
data_source my_postgres:
  type: postgres
  connection:
    host: localhost
    port: 5432
    user: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    database: analytics
  schema: public
```

### Snowflake

```yaml
data_source my_snowflake:
  type: snowflake
  connection:
    username: ${SNOWFLAKE_USER}
    password: ${SNOWFLAKE_PASSWORD}
    account: my_account.us-east-1
    database: ANALYTICS
    warehouse: TRANSFORM_WH
    role: SODA_ROLE
  schema: PUBLIC
```

### BigQuery

```yaml
data_source my_bigquery:
  type: bigquery
  connection:
    account_info_json_path: /path/to/service-account.json
    project_id: my-gcp-project
    dataset: analytics
```

### Databricks

```yaml
data_source my_databricks:
  type: databricks
  connection:
    host: dbc-xxxxxxxx-xxxx.cloud.databricks.com
    http_path: /sql/1.0/warehouses/xxxxxxxxxxxxxxxx
    token: ${DATABRICKS_TOKEN}
  schema: default
```

## Environment Variables

Use `${VAR_NAME}` syntax for sensitive values. Set via shell or `.env` file before running scans.

## Soda Cloud Connection

```yaml
soda_cloud:
  host: cloud.soda.io
  api_key_id: ${SODA_CLOUD_API_KEY}
  api_key_secret: ${SODA_CLOUD_API_SECRET}
```

## Testing and Multiple Sources

```bash
soda test-connection -d my_postgres -c configuration.yml
```

A single `configuration.yml` can contain multiple data sources.

## Common Mistakes

### Wrong

```yaml
# Hardcoded credentials, missing schema
data_source prod:
  type: snowflake
  connection:
    username: admin
    password: secret123
```

### Correct

```yaml
data_source prod:
  type: snowflake
  connection:
    username: ${SNOWFLAKE_USER}
    password: ${SNOWFLAKE_PASSWORD}
    account: my_account.us-east-1
    database: ANALYTICS
    warehouse: SODA_WH
    role: SODA_ROLE
  schema: PUBLIC
```

## Related

- [SodaCL Syntax](../concepts/sodacl.md)
- [CI/CD Integration](../patterns/ci-cd-integration.md)
