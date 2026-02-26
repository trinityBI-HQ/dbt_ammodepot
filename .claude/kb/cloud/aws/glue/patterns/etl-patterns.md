# ETL Patterns

> **Purpose**: Production patterns for incremental loads, error handling, and schema evolution
> **MCP Validated**: 2026-02-19

## When to Use

- Building incremental data pipelines that process only new data
- Handling schema changes gracefully in evolving data sources
- Implementing error handling with dead-letter queues for failed records

## Incremental Load with Bookmarks

```python
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import *
from pyspark.context import SparkContext

sc = SparkContext()
glue_ctx = GlueContext(sc)
job = Job(glue_ctx)
job.init(args["JOB_NAME"], args)

# Bookmarks track last processed file/row
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="raw_db",
    table_name="events",
    transformation_ctx="events_source",  # Required for bookmark tracking
    additional_options={
        "boundedFiles": "100",  # Process max 100 files per run
    },
)

if dyf.count() == 0:
    print("No new data to process")
    job.commit()
    return

# Transform
dyf = ApplyMapping.apply(
    frame=dyf,
    mappings=[
        ("event_id", "string", "event_id", "string"),
        ("timestamp", "string", "event_ts", "timestamp"),
        ("payload", "string", "payload", "string"),
    ],
    transformation_ctx="mapping",
)

# Write to target
glue_ctx.write_dynamic_frame.from_options(
    frame=dyf,
    connection_type="s3",
    connection_options={
        "path": "s3://data-lake/silver/events/",
        "partitionKeys": ["year", "month"],
    },
    format="glueparquet",
    format_options={"compression": "snappy"},
    transformation_ctx="write_target",
)

job.commit()  # Commits bookmark state
```

## Schema Evolution Handling

```python
# ResolveChoice handles columns with mixed types
dyf_resolved = dyf.resolveChoice(
    specs=[
        ("price", "cast:double"),       # Force to double
        ("quantity", "cast:int"),        # Force to int
        ("metadata", "make_struct"),     # Merge struct variants
    ]
)

# Relationalize flattens nested JSON
dyf_flat = dyf.relationalize(
    root_table_name="events",
    staging_path="s3://temp/glue/relationalize/",
)
# Returns DynamicFrameCollection: root table + nested arrays as separate tables
```

## Error Handling Pattern

```python
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, lit, current_timestamp

df = dyf.toDF()

# Separate good and bad records
good_df = df.filter(
    col("order_id").isNotNull() &
    (col("amount") > 0) &
    col("email").rlike("^[^@]+@[^@]+\\.[^@]+$")
)

bad_df = df.subtract(good_df).withColumn(
    "error_reason",
    lit("validation_failed")
).withColumn(
    "error_ts",
    current_timestamp()
)

# Write good records to target
good_dyf = DynamicFrame.fromDF(good_df, glue_ctx, "good")
glue_ctx.write_dynamic_frame.from_options(
    frame=good_dyf,
    connection_type="s3",
    connection_options={"path": "s3://lake/silver/orders/"},
    format="glueparquet",
)

# Write bad records to dead-letter location
bad_dyf = DynamicFrame.fromDF(bad_df, glue_ctx, "bad")
glue_ctx.write_dynamic_frame.from_options(
    frame=bad_dyf,
    connection_type="s3",
    connection_options={"path": "s3://lake/quarantine/orders/"},
    format="json",
)
```

## Upsert Pattern (S3 with Iceberg)

```python
# Using Apache Iceberg for ACID upserts on S3
# Glue 5.1: Iceberg 1.10.0 with format v3 support
spark = glue_ctx.spark_session

spark.sql("""
    MERGE INTO glue_catalog.silver.customers AS target
    USING (SELECT * FROM glue_catalog.raw.customers_cdc) AS source
    ON target.customer_id = source.customer_id
    WHEN MATCHED AND source.op = 'D' THEN DELETE
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
```

### Iceberg Format v3 (Glue 5.1+)

Glue 5.1 supports Iceberg format v3, which adds:
- **Row-level lineage** via default sort order
- **Nanosecond timestamp** precision
- **Multi-argument transforms** for partition specs

```python
# Create Iceberg v3 table in Glue 5.1
spark.sql("""
    CREATE TABLE glue_catalog.silver.events (
        event_id STRING,
        event_ts TIMESTAMP_NTZ,
        payload STRING
    )
    USING iceberg
    TBLPROPERTIES ('format-version' = '3')
""")
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `boundedFiles` | None | Max files per bookmark batch |
| `boundedSize` | None | Max bytes per bookmark batch |
| `job-bookmark-option` | disabled | `enable` / `disable` / `pause` |
| `--enable-auto-scaling` | false | Auto-scale workers based on load |

## Example Usage

```bash
# Run incremental ETL
aws glue start-job-run \
  --job-name sales-etl \
  --arguments '{"--job-bookmark-option":"job-bookmark-enable"}'

# Reset bookmarks to reprocess all data
aws glue reset-job-bookmark --job-name sales-etl
```

## See Also

- [ETL Jobs](../concepts/etl-jobs.md)
- [Performance Optimization](../patterns/performance-optimization.md)
