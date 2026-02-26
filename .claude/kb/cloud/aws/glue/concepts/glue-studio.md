# Glue Studio

> **Purpose**: Visual ETL authoring, monitoring, and job management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

AWS Glue Studio provides a visual interface for creating, running, and monitoring ETL jobs. It offers a drag-and-drop DAG editor where nodes represent sources, transforms, and targets. Studio generates PySpark code automatically and provides real-time job monitoring with data previews.

## Visual Editor Components

| Component | Description |
|-----------|-------------|
| **Source nodes** | Read from S3, Catalog tables, JDBC, Kafka, Kinesis |
| **Transform nodes** | Filter, join, map, aggregate, custom SQL, custom code |
| **Target nodes** | Write to S3, Catalog tables, JDBC, Redshift |
| **Custom nodes** | User-defined Python/Spark transforms |

## DAG Editor

```
[S3 Source: orders] → [Filter: amount > 0] → [Join] → [S3 Target: enriched/]
                                                ↑
[Catalog: customers] → [SelectFields] ─────────┘
```

Each node is configurable:
- **Source**: database, table, pushdown predicates
- **Transform**: expressions, SQL, column mappings
- **Target**: format (Parquet/JSON/CSV), partitioning, compression

## Built-in Transforms

| Transform | Purpose |
|-----------|---------|
| **ApplyMapping** | Rename/retype columns |
| **Filter** | Row-level filtering |
| **Join** | Inner, outer, left, right joins |
| **SelectFields** | Column projection |
| **DropFields** | Remove columns |
| **DropNullFields** | Remove null-only columns |
| **Aggregate** | Group by + aggregation functions |
| **FillMissingValues** | ML-based imputation |
| **DetectSensitive** | PII detection (names, SSNs, emails) |
| **Custom SQL** | Arbitrary SparkSQL |
| **Custom Code** | Python/Scala snippets |

## Custom Transform Node

```python
# Custom code node receives DynamicFrameCollection
def MyTransform(glueContext, dfc) -> DynamicFrameCollection:
    dyf = dfc.select(list(dfc.keys())[0])
    df = dyf.toDF()

    # Custom business logic
    df = df.withColumn("total_with_tax", df["amount"] * 1.08)

    result = DynamicFrame.fromDF(df, glueContext, "result")
    return DynamicFrameCollection({"CustomTransform": result}, glueContext)
```

## Job Monitoring

Studio provides a monitoring dashboard with:

| Metric | Description |
|--------|-------------|
| **Job Run Status** | Succeeded, Failed, Running, Timeout |
| **Duration** | Total wall-clock time |
| **DPU Hours** | Billable compute consumed |
| **Data Preview** | Sample output at each node |
| **Spark UI** | Link to Spark UI for detailed profiling |
| **CloudWatch Logs** | Driver and executor logs |
| **Error Details** | Stack traces and failure reasons |

## Notebooks (Interactive Sessions)

Glue Studio offers Jupyter-style notebooks backed by Glue Interactive Sessions:

```python
%glue_version 4.0
%worker_type G.1X
%number_of_workers 5
%idle_timeout 60

# Interactive development with live Spark cluster
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db", table_name="orders"
)
dyf.show(5)  # Preview data instantly
```

**Benefits:** Iterate on transforms interactively before deploying as a scheduled job.

## Visual ETL vs Script

| Factor | Visual ETL | Script |
|--------|-----------|--------|
| Learning curve | Low | Medium-High |
| Flexibility | Standard transforms | Unlimited |
| Version control | JSON job definition | Python/Scala files |
| Complex logic | Limited | Full Spark API |
| Team adoption | Non-engineers | Data engineers |

**Recommendation:** Start with Visual ETL for simple pipelines. Switch to scripts for complex business logic, custom libraries, or when version control is critical.

## Related

- [ETL Jobs](../concepts/etl-jobs.md)
- [ETL Patterns](../patterns/etl-patterns.md)
