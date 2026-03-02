# Onehouse Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Product Modules

| Module | Purpose | Table Formats |
|--------|---------|---------------|
| **OneFlow** | Managed ingestion (CDC, streaming, files) | Hudi, Iceberg, Delta |
| **Table Optimizer** | Compaction, clustering, cleaning | Hudi, Iceberg, Delta |
| **OneSync** | Multi-catalog synchronization | All via XTable |
| **LakeView** | Free observability and monitoring | Hudi (primary) |
| **OCR** | Serverless Spark compute runtime | All formats |
| **LakeBase** | Foundation lakehouse storage layer | Hudi native |
| **Quanton** | SQL/Spark execution engine on OCR | All formats |

## Supported Integrations

| Category | Integrations |
|----------|-------------|
| **Query Engines** | Snowflake, Databricks, BigQuery, Athena, Redshift, Trino, ClickHouse, Spark |
| **Catalogs** | Snowflake Catalog, Unity Catalog, Google Data Catalog, AWS Glue, Hive Metastore |
| **Ingestion Sources** | PostgreSQL, MySQL, SQL Server, MongoDB, Kafka, S3/GCS files |
| **File Formats** | Avro, CSV, JSON, Parquet, Proto, XML |
| **Cloud Providers** | AWS, GCP, Azure (BYOC deployment) |
| **Table Formats** | Apache Hudi, Apache Iceberg, Delta Lake |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Managed CDC to lakehouse | OneFlow with database source |
| Optimize existing Hudi tables | Table Optimizer (compaction + clustering) |
| Query lakehouse from Snowflake | OneSync catalog sync + Iceberg format |
| Monitor table health for free | LakeView (metadata-only, no compute cost) |
| Multi-format interoperability | Apache XTable (Hudi source, Iceberg/Delta targets) |
| Streaming ingestion from Kafka | OneFlow with Kafka source |
| Serverless Spark workloads | OCR with Quanton engine |
| Bronze-to-silver transformations | OneFlow incremental ETL pipelines |

## Table Optimizer Operations

| Operation | Purpose | Config Options |
|-----------|---------|----------------|
| **Compaction** | Merge log files into base files (MoR) | Frequency, bytes-per-compaction |
| **Clustering** | Re-organize data layout by key columns | Keys, strategy, frequency |
| **Cleaning** | Remove files beyond retention period | Frequency, retention window |

## Performance Benchmarks

| Metric | Improvement | Context |
|--------|-------------|---------|
| Write speed (upserts) | Up to 10x faster | vs. traditional batch approaches |
| Query acceleration | 2-30x faster | With table optimization + OCR |
| Cost savings | 20-80% reduction | Serverless OCR vs. always-on clusters |
| Ingestion latency | Minute-level freshness | CDC and streaming sources |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Run compaction on every commit | Set frequency-based compaction schedules |
| Skip clustering on large tables | Configure clustering keys matching query patterns |
| Use single table format for all engines | Use XTable to expose Hudi data as Iceberg/Delta |
| Manually manage Spark clusters | Use OCR serverless compute with auto-scaling |
| Monitor tables by querying data files | Use LakeView metadata-only observability |
| Provision dedicated compute per table | Share OCR clusters across table services |

## Related Documentation

| Topic | Path |
|-------|------|
| Platform Architecture | `concepts/platform-architecture.md` |
| Full Index | `index.md` |
| Apache Iceberg (format) | `../../table-formats/apache-iceberg/index.md` |
| Snowflake (query engine) | `../snowflake/index.md` |
