# Spark Connector

> **Purpose**: Apache Spark integration for reading and writing Snowflake data
> **MCP Validated**: 2026-02-19

## When to Use

- Spark-based ETL pipelines reading from or writing to Snowflake
- Databricks workloads with Snowflake as source/sink
- Complex transformations in Spark before loading to Snowflake
- Migrating Spark workloads that interact with Snowflake

## Implementation

```python
# PySpark configuration
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SnowflakeIntegration") \
    .config("spark.jars.packages",
            "net.snowflake:spark-snowflake_2.12:3.0.0,"
            "net.snowflake:snowflake-jdbc:3.14.4") \
    .getOrCreate()

# Snowflake connection options
sf_options = {
    "sfURL": "account.snowflakecomputing.com",
    "sfUser": "username",
    "sfPassword": "password",
    "sfDatabase": "ANALYTICS_DB",
    "sfSchema": "PUBLIC",
    "sfWarehouse": "SPARK_WH",
    "sfRole": "DATA_ENGINEER"
}

# Read from Snowflake
df = spark.read \
    .format("snowflake") \
    .options(**sf_options) \
    .option("dbtable", "orders") \
    .load()

# Read with query pushdown
df = spark.read \
    .format("snowflake") \
    .options(**sf_options) \
    .option("query", """
        SELECT customer_id, SUM(amount) as total
        FROM orders
        WHERE order_date >= '2024-01-01'
        GROUP BY customer_id
    """) \
    .load()

# Write to Snowflake
df.write \
    .format("snowflake") \
    .options(**sf_options) \
    .option("dbtable", "orders_processed") \
    .mode("append") \
    .save()

# Write with overwrite
df.write \
    .format("snowflake") \
    .options(**sf_options) \
    .option("dbtable", "orders_snapshot") \
    .mode("overwrite") \
    .save()
```

## Configuration

| Option | Description |
|--------|-------------|
| `sfURL` | Snowflake account URL |
| `sfUser` / `sfPassword` | Authentication credentials |
| `sfDatabase` / `sfSchema` | Target database and schema |
| `sfWarehouse` | Warehouse for query execution |
| `dbtable` | Table name to read/write |
| `query` | Custom SQL query (read only) |
| `autopushdown` | Enable query pushdown (default: on) |

| Write Mode | Behavior |
|------------|----------|
| `append` | Add rows to existing table |
| `overwrite` | Replace table contents |
| `errorifexists` | Fail if table exists |
| `ignore` | Skip if table exists |

## Example Usage

```python
# Databricks notebook pattern
from pyspark.sql.functions import col, sum, avg

# Use secrets for credentials (Databricks)
sf_options = {
    "sfURL": dbutils.secrets.get("snowflake", "url"),
    "sfUser": dbutils.secrets.get("snowflake", "user"),
    "sfPassword": dbutils.secrets.get("snowflake", "password"),
    "sfDatabase": "ANALYTICS_DB",
    "sfSchema": "STAGING",
    "sfWarehouse": "ETL_WH",
    "sfRole": "ETL_ROLE"
}

# Read source data
orders_df = spark.read.format("snowflake") \
    .options(**sf_options) \
    .option("dbtable", "RAW_ORDERS") \
    .load()

# Transform in Spark
aggregated_df = orders_df \
    .filter(col("status") == "completed") \
    .groupBy("customer_id", "region") \
    .agg(
        sum("amount").alias("total_amount"),
        avg("amount").alias("avg_amount")
    )

# Write results back to Snowflake
aggregated_df.write.format("snowflake") \
    .options(**sf_options) \
    .option("dbtable", "CUSTOMER_METRICS") \
    .mode("overwrite") \
    .save()

# Alternative: Use Snowpark instead of Spark connector
# Snowpark runs transformations in Snowflake, no Spark cluster needed
from snowflake.snowpark import Session
from snowflake.snowpark.functions import sum as sf_sum

session = Session.builder.configs(sf_options).create()
orders = session.table("RAW_ORDERS")
result = orders.filter(col("status") == "completed") \
    .group_by("customer_id") \
    .agg(sf_sum("amount").alias("total"))
result.write.save_as_table("CUSTOMER_TOTALS", mode="overwrite")
```

## See Also

- [python-connector](../patterns/python-connector.md)
- [virtual-warehouses](../concepts/virtual-warehouses.md)
