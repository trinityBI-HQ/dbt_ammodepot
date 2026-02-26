# Spark Validation

> **MCP Validated:** 2026-02-19

## Overview

Great Expectations supports PySpark DataFrames as a first-class backend. This pattern covers connecting GX to Spark data, validating distributed DataFrames, and integrating with Spark pipelines.

## Installation

```bash
pip install 'great_expectations[spark]'
```

Requires an active Spark session.

## Basic Spark Validation

```python
import great_expectations as gx
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("gx_validation").getOrCreate()

# Read data
df = spark.read.parquet("s3://data-lake/events/")

# Set up GX
context = gx.get_context()
data_source = context.data_sources.add_spark(name="spark_source")
data_asset = data_source.add_dataframe_asset(name="events")
batch_def = data_asset.add_batch_definition_whole_dataframe("full_batch")

# Create suite
suite = context.suites.add(gx.ExpectationSuite(name="events_suite"))
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="event_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeInSet(
        column="event_type", value_set=["click", "view", "purchase"]
    )
)
suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(min_value=1000)
)

# Validate
validation_def = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="events_vd", data=batch_def, suite=suite
    )
)
result = validation_def.run(batch_parameters={"dataframe": df})
print(result.success)
```

## Spark with SQL Tables

For data in a Spark catalog (Hive, Delta, Iceberg):

```python
data_source = context.data_sources.add_spark(name="catalog_source")
data_asset = data_source.add_table_asset(
    name="orders_table", table_name="catalog.schema.orders"
)
batch_def = data_asset.add_batch_definition_whole_table("full_table")

validation_def = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="orders_vd", data=batch_def, suite=suite
    )
)
result = validation_def.run()
```

## Partitioned Validation

Validate specific partitions instead of full tables:

```python
data_asset = data_source.add_table_asset(
    name="daily_events", table_name="events"
)

# Daily partitioning
batch_def = data_asset.add_batch_definition_daily(
    name="daily_batch", column="event_date"
)

# Validate specific day
batch = batch_def.get_batch(
    batch_parameters={"event_date": "2026-02-12"}
)
result = batch.validate(
    gx.expectations.ExpectTableRowCountToBeBetween(min_value=100)
)
```

## Databricks Integration

```python
# On Databricks, Spark session is pre-configured
context = gx.get_context()

# Use Databricks SQL data source for Unity Catalog tables
data_source = context.data_sources.add_databricks_sql(
    name="databricks",
    connection_string="${DATABRICKS_SQL_CONNECTION}",
)
data_asset = data_source.add_table_asset(
    name="orders", table_name="catalog.schema.orders"
)
```

## Spark Pipeline Pattern

Integrate GX as a quality gate within a Spark ETL job:

```python
from pyspark.sql import SparkSession
import great_expectations as gx

def run_pipeline():
    spark = SparkSession.builder.getOrCreate()

    # Extract
    raw_df = spark.read.parquet("s3://raw/events/")

    # Validate bronze
    validate_dataframe(raw_df, "bronze_events_suite")

    # Transform
    clean_df = raw_df.dropDuplicates(["event_id"]).filter("event_type IS NOT NULL")

    # Validate silver
    validate_dataframe(clean_df, "silver_events_suite")

    # Load
    clean_df.write.mode("overwrite").saveAsTable("silver.events")


def validate_dataframe(df, suite_name: str):
    context = gx.get_context()
    source = context.data_sources.add_spark(name="pipe_source")
    asset = source.add_dataframe_asset(name="pipe_asset")
    batch_def = asset.add_batch_definition_whole_dataframe("batch")

    suite = context.suites.get(suite_name)

    vd = context.validation_definitions.add(
        gx.ValidationDefinition(
            name=f"vd_{suite_name}", data=batch_def, suite=suite
        )
    )
    result = vd.run(batch_parameters={"dataframe": df})

    if not result.success:
        raise RuntimeError(f"Quality gate '{suite_name}' failed")
```

## Performance Considerations

| Consideration | Recommendation |
|--------------|----------------|
| Large DataFrames | Use partitioned batch definitions to validate subsets |
| Aggregate expectations | Efficient — Spark computes aggregates natively |
| Row-level expectations | May trigger full DataFrame scans — use `mostly` |
| Caching | Cache DataFrame before validation if reused downstream |
| Cluster sizing | GX validation runs on Spark executors, same as transforms |

## See Also

- [../concepts/data-sources.md](../concepts/data-sources.md) - Data Source configuration
- [pipeline-integration.md](pipeline-integration.md) - Orchestrator integration
- [custom-expectations.md](custom-expectations.md) - Custom SQL expectations for Spark SQL
