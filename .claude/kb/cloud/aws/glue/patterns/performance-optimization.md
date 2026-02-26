# Performance Optimization

> **Purpose**: Right-size workers, reduce data scans, and optimize Spark execution
> **MCP Validated**: 2026-02-19

## When to Use

- Glue jobs are slow or exceeding DPU budgets
- OOM errors on executors or driver
- Processing TB-scale datasets and need cost efficiency

## Pushdown Predicates

Filter at the source to avoid reading unnecessary data:

```python
# S3 partition pruning -- only reads matching partitions
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db",
    table_name="orders",
    push_down_predicate="year='2025' AND month='01'",
    transformation_ctx="source",
)

# Catalog partition predicate -- uses partition indexes
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db",
    table_name="orders",
    additional_options={
        "catalogPartitionPredicate": "year='2025' AND month BETWEEN '01' AND '06'",
    },
    transformation_ctx="source",
)
```

**How they differ:**

| Predicate | Layer | Best For |
|-----------|-------|----------|
| `push_down_predicate` | S3 file listing | Simple equality/range on partitions |
| `catalogPartitionPredicate` | Catalog API | Millions of partitions, uses indexes |

Use both together for maximum pruning:
```python
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db",
    table_name="events",
    push_down_predicate="year='2025'",
    additional_options={
        "catalogPartitionPredicate": "month='06' AND day >= '15'",
    },
)
```

## Worker Sizing Guide

```
Start: G.1X with 10 workers
  ↓ If OOM errors
Increase: G.2X (same workers) -- doubles memory
  ↓ If still OOM or heavy shuffle
Increase: G.4X or R.2X -- for join-heavy workloads
  ↓ If slow but no OOM
Scale out: More G.1X workers -- better parallelism
```

### Auto Scaling

```python
job = glue.create_job(
    Name="auto-scale-etl",
    WorkerType="G.1X",
    NumberOfWorkers=20,  # Maximum workers
    DefaultArguments={
        "--enable-auto-scaling": "true",
    },
)
# Glue scales between 2 and NumberOfWorkers based on load
```

## Grouping and Unbundling

Control how many S3 files map to Spark partitions:

```python
# Grouping: merge many small files into fewer partitions
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db",
    table_name="many_small_files",
    additional_options={
        "groupFiles": "inPartition",     # Group within each partition
        "groupSize": "134217728",        # 128 MB target per group
    },
)

# Unbundling: split large files across multiple partitions
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db",
    table_name="few_huge_files",
    additional_options={
        "boundedSize": "536870912",  # 512 MB per batch
    },
)
```

## Write Optimization

```python
# Repartition before writing for optimal file sizes (128-512 MB)
df = dyf.toDF()
target_files = max(1, df.rdd.getNumPartitions() // 4)
df = df.repartition(target_files)

# Coalesce for fewer output files (no shuffle)
df = df.coalesce(10)

# Write with compression
glue_ctx.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(df, glue_ctx, "output"),
    connection_type="s3",
    connection_options={"path": "s3://lake/silver/orders/"},
    format="glueparquet",
    format_options={"compression": "snappy"},
)
```

## JDBC Read Optimization

```python
# Parallel JDBC reads using hashfield
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="db",
    table_name="jdbc_orders",
    additional_options={
        "hashfield": "order_id",       # Column to hash-partition
        "hashpartitions": "20",        # Number of parallel connections
    },
)
```

## Glue 5.0/5.1 Optimizations

Glue 5.0+ (Spark 3.5) adds significant performance improvements:

- **Spark 3.5.6 AQE enhancements**: Improved adaptive query execution with better shuffle partition coalescing
- **Spark-native fine-grained access control** (Glue 5.1): Lake Formation FGAC runs at the Spark level for lower overhead vs. catalog-level filtering
- **Iceberg 1.10.0** (Glue 5.1): Faster metadata operations, format v3, materialized views

```python
# Glue 5.1 job configuration
job = glue.create_job(
    Name="optimized-etl-v5",
    GlueVersion="5.1",
    WorkerType="G.1X",
    NumberOfWorkers=10,
    DefaultArguments={
        "--enable-auto-scaling": "true",
        "--datalake-formats": "iceberg",  # Enable Iceberg support
    },
)
```

## Spark Configuration Tuning

```python
# In job parameters or script
spark.conf.set("spark.sql.shuffle.partitions", "200")  # Default: 200
spark.conf.set("spark.sql.adaptive.enabled", "true")   # AQE (Glue 4.0+)
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.files.maxPartitionBytes", "134217728")  # 128 MB
spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
```

## Monitoring Performance

Enable Spark UI, CloudWatch metrics, and job profiler for bottleneck detection:

```python
"--enable-metrics": "",
"--enable-spark-ui": "true",
"--spark-event-logs-path": "s3://logs/spark-ui/",
"--enable-job-insights": "true",
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `spark.sql.shuffle.partitions` | 200 | Reduce for small datasets |
| `spark.sql.adaptive.enabled` | true (Glue 4.0+) | Adaptive query execution |
| `groupSize` | None | Target bytes per file group |
| `boundedFiles` | None | Max files per bookmark run |

## See Also

- [ETL Jobs](../concepts/etl-jobs.md)
- [ETL Patterns](../patterns/etl-patterns.md)
