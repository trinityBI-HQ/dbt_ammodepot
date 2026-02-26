# AWS Glue Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Worker Types

| Type | DPU | vCPUs | Memory | Disk | Use Case |
|------|-----|-------|--------|------|----------|
| G.025X | 0.25 | 2 | 4 GB | 84 GB | Low-volume streaming |
| G.1X | 1 | 4 | 16 GB | 94 GB | Standard ETL transforms |
| G.2X | 2 | 8 | 32 GB | 138 GB | Memory-intensive transforms |
| G.4X | 4 | 16 | 64 GB | 256 GB | Large aggregations/joins |
| G.8X | 8 | 32 | 128 GB | 512 GB | Very large workloads |
| R.1X | 1 | 4 | 32 GB | 128 GB | Memory-optimized (2x RAM) |
| R.2X | 2 | 8 | 64 GB | 256 GB | Heavy caching/shuffling |

## Job Types

| Type | Engine | Use Case | Min Workers |
|------|--------|----------|-------------|
| Spark | Apache Spark | Large-scale ETL | 2 DPU |
| Spark Streaming | Spark Structured Streaming | Real-time ETL | 2 DPU |
| Python Shell | Python 3.9+ | Small tasks, API calls | 0.0625/1 DPU |
| Ray | Ray runtime | ML workloads, distributed Python | 2 DPU |

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `aws glue start-job-run --job-name X` | Start ETL job |
| `aws glue get-job-runs --job-name X` | List job runs |
| `aws glue start-crawler --name X` | Start crawler |
| `aws glue get-tables --database-name X` | List catalog tables |
| `aws glue create-database --database-input '{"Name":"X"}'` | Create catalog DB |
| `aws glue batch-get-partition` | Get partition metadata |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Small scripts, API calls | Python Shell job |
| Large-scale ETL (>1 GB) | Spark job (G.1X+) |
| Real-time data ingestion | Spark Streaming (G.025X) |
| Memory-heavy joins/caches | R-type workers |
| Schema discovery | Crawlers + Data Catalog |
| Data validation | DQDL rules |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use DynamicFrame for complex SQL | Convert to DataFrame with `.toDF()` |
| Skip job bookmarks for incremental | Enable bookmarks + checkpoint S3 path |
| Run crawlers on every job run | Schedule crawlers separately, use catalog API |
| Hardcode partition paths | Use pushdown predicates for pruning |
| Use G.1X for everything | Right-size: start G.1X, scale up if OOM |
| Ignore Glue version | Use Glue 5.1 (Spark 3.5.6, Python 3.11) |

## Glue Versions

| Version | Spark | Python | Scala | Iceberg | Key Features |
|---------|-------|--------|-------|---------|--------------|
| Glue 5.1 | 3.5.6 | 3.11 | 2.12 | 1.10.0 | Iceberg v3, materialized views, Spark-native Lake Formation |
| Glue 5.0 | 3.5 | 3.11 | 2.12 | 1.7.1 | Data Catalog views, full Lake Formation DML |
| Glue 4.0 | 3.3.0 | 3.10 | 2.12 | -- | AQE, faster startup (legacy) |

Also ships: Hudi 1.0.2, Delta Lake 3.3.2 (Glue 5.1). Glue 4.0 is not auto-migrated; 5.0/5.1 are opt-in.

## Key Job Parameters

| Parameter | Description |
|-----------|-------------|
| `--job-bookmark-option` | `job-bookmark-enable` / `disable` / `pause` |
| `--enable-metrics` | Enable CloudWatch Spark metrics |
| `--enable-spark-ui` | Enable Spark UI logs to S3 |
| `--TempDir` | S3 temp directory for intermediate data |
| `--additional-python-modules` | Pip packages to install |
| `--conf` | Spark configuration overrides |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/data-catalog.md` |
| Full Index | `index.md` |
