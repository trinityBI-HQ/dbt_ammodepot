# Data Sources

> **MCP Validated:** 2026-02-19

## Overview

Data Sources define how Great Expectations connects to your data. In GX 1.x, you configure Data Sources, Data Assets, and Batch Definitions using the fluent Python API through the Data Context.

**Hierarchy:** Data Source → Data Asset → Batch Definition → Batch

## Data Source Types

| Method | Backend | Extra Install |
|--------|---------|---------------|
| `add_pandas()` | Pandas DataFrames | None (included) |
| `add_spark()` | PySpark DataFrames | `great_expectations[spark]` |
| `add_postgres()` | PostgreSQL | `great_expectations[postgresql]` |
| `add_snowflake()` | Snowflake | `great_expectations[snowflake]` |
| `add_databricks_sql()` | Databricks SQL | `great_expectations[databricks]` |
| `add_redshift()` | Amazon Redshift | `great_expectations[redshift]` |
| `add_sql()` | Generic SQLAlchemy | Dialect-specific driver |

## Creating Data Sources

### Pandas

```python
import great_expectations as gx

context = gx.get_context()
data_source = context.data_sources.add_pandas(name="my_pandas")
```

### Spark

```python
data_source = context.data_sources.add_spark(name="my_spark")
```

### SQL (PostgreSQL)

```python
connection_string = "postgresql+psycopg2://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}"
data_source = context.data_sources.add_postgres(
    name="prod_db", connection_string=connection_string
)
```

### Snowflake

```python
data_source = context.data_sources.add_snowflake(
    name="snowflake_db",
    account="${SNOWFLAKE_ACCOUNT}",
    user="${SNOWFLAKE_USER}",
    password="${SNOWFLAKE_PASSWORD}",
    database="ANALYTICS",
    schema="PUBLIC",
    warehouse="COMPUTE_WH",
)
```

## Data Assets

Data Assets represent specific collections of records within a Data Source.

| Method | Use Case |
|--------|----------|
| `add_dataframe_asset(name)` | In-memory DataFrame (Pandas/Spark) |
| `add_table_asset(name, table_name)` | Database table |
| `add_query_asset(name, query)` | Custom SQL query |

```python
# Table asset
asset = data_source.add_table_asset(name="orders", table_name="raw_orders")

# Query asset
asset = data_source.add_query_asset(
    name="recent_orders",
    query="SELECT * FROM orders WHERE created_at > CURRENT_DATE - INTERVAL '7 days'"
)

# DataFrame asset
asset = data_source.add_dataframe_asset(name="df_asset")
```

## Batch Definitions

Batch Definitions control how records are organized for validation.

| Method | Partitioning |
|--------|-------------|
| `add_batch_definition_whole_dataframe(name)` | All rows (DataFrame) |
| `add_batch_definition_whole_table(name)` | All rows (SQL table) |
| `add_batch_definition_daily(name, column)` | Partition by day |
| `add_batch_definition_monthly(name, column)` | Partition by month |
| `add_batch_definition_yearly(name, column)` | Partition by year |

```python
# Whole table
batch_def = asset.add_batch_definition_whole_table("full_table")

# Daily partitioning
batch_def = asset.add_batch_definition_daily(
    name="daily_orders", column="created_at"
)
```

## Retrieving a Batch

```python
# SQL/table batch
batch = batch_def.get_batch()

# DataFrame batch (pass data at runtime)
batch = batch_def.get_batch(batch_parameters={"dataframe": df})
```

## Credentials

Never hardcode credentials. Use environment variable substitution:

```python
# GX resolves ${VAR_NAME} from environment variables
connection_string = "postgresql+psycopg2://${DB_USER}:${DB_PASS}@${DB_HOST}/mydb"
```

## See Also

- [data-context.md](data-context.md) - Managing the context that holds Data Sources
- [expectations.md](expectations.md) - Validating data from your sources
- [../patterns/spark-validation.md](../patterns/spark-validation.md) - PySpark-specific patterns
