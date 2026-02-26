# ETL Jobs

> **Purpose**: Serverless Spark-based data transformation and movement
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

AWS Glue ETL jobs run Apache Spark workloads on fully managed infrastructure. Jobs can be authored in Python (PySpark) or Scala, and Glue handles provisioning, scaling, and monitoring. The DPU (Data Processing Unit) is the billing unit: 1 DPU = 4 vCPUs + 16 GB RAM.

## Job Types

| Type | Engine | Best For |
|------|--------|----------|
| **Spark** | PySpark/Scala on Spark 3.5 | Large ETL (GB-TB scale) |
| **Spark Streaming** | Structured Streaming | Real-time from Kafka/Kinesis |
| **Python Shell** | Pure Python (no Spark) | Small scripts, API calls, <1 DPU |
| **Ray** | Ray distributed runtime | ML workloads, distributed Python |

## Glue Versions

| Version | Spark | Python | Scala | Key Features |
|---------|-------|--------|-------|--------------|
| Glue 5.1 | 3.5.6 | 3.11 | 2.12 | Iceberg 1.10.0, Iceberg v3 format, materialized views, Spark-native Lake Formation FGAC |
| Glue 5.0 | 3.5 | 3.11 | 2.12 | Iceberg 1.7.1, Hudi 0.15, Delta 3.3, Data Catalog views, full Lake Formation DML |
| Glue 4.0 | 3.3.0 | 3.10 | 2.12 | Optimized Spark, faster startup (legacy, not auto-migrated) |
| Glue 3.0 | 3.1.1 | 3.7 | 2.12 | Spark 3 features |

Always use **Glue 5.1** for new jobs. Glue 5.0/5.1 are opt-in (set `GlueVersion` explicitly).

## DynamicFrame vs DataFrame

```python
from awsglue.context import GlueContext
from pyspark.context import SparkContext

sc = SparkContext()
glue_ctx = GlueContext(sc)

# DynamicFrame -- flexible schema, handles messy data
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db", table_name="orders"
)

# Convert to DataFrame for complex operations
df = dyf.toDF()
df_filtered = df.filter(df.amount > 100)

# Convert back if needed
dyf_result = DynamicFrame.fromDF(df_filtered, glue_ctx, "result")
```

**DynamicFrame advantages:**
- Handles schema inconsistencies (same column, different types)
- `ResolveChoice` for ambiguous types
- `Relationalize` for flattening nested JSON
- Native Catalog integration

**Use DataFrame when:**
- Complex SQL, window functions, or aggregations
- Using third-party Spark libraries
- Performance-critical operations

## Job Bookmarks

Bookmarks track processed data to enable incremental loads:

```python
# Enable in job parameters: --job-bookmark-option job-bookmark-enable
# Glue tracks which S3 files/JDBC rows were already processed

dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db",
    table_name="orders",
    transformation_ctx="orders_source",  # Required for bookmarks
)
# Only unprocessed data is returned
```

Bookmark state stored per `transformation_ctx`. Reset via:
```bash
aws glue reset-job-bookmark --job-name my-etl-job
```

## Worker Type Selection

| Scenario | Worker | Why |
|----------|--------|-----|
| Standard transforms, joins | G.1X | Baseline, cost-effective |
| Large aggregations, wide tables | G.2X | 2x memory prevents OOM |
| ML feature engineering | G.4X | Heavy compute + memory |
| Caching large datasets | R.1X/R.2X | Double memory vs G-series |
| Low-volume streaming | G.025X | Minimum cost for streaming |

## Key Job Parameters

```python
job = glue.create_job(
    Name="sales-etl",
    Role="arn:aws:iam::role/GlueETLRole",
    Command={"Name": "glueetl", "ScriptLocation": "s3://scripts/etl.py"},
    GlueVersion="5.1",
    WorkerType="G.1X",
    NumberOfWorkers=10,
    DefaultArguments={
        "--job-bookmark-option": "job-bookmark-enable",
        "--enable-metrics": "",
        "--enable-spark-ui": "true",
        "--spark-event-logs-path": "s3://logs/spark-ui/",
        "--TempDir": "s3://temp/glue/",
        "--additional-python-modules": "pandas==2.0.0,requests",
    },
)
```

## Common Mistakes

### Wrong

```python
# Reading entire dataset without pushdown
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db", table_name="huge_table"
)  # Reads ALL partitions
```

### Correct

```python
# Apply pushdown predicate to read only needed partitions
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db",
    table_name="huge_table",
    push_down_predicate="year='2025' AND month='01'",
)
```

## Related

- [Performance Optimization](../patterns/performance-optimization.md)
- [ETL Patterns](../patterns/etl-patterns.md)
