# OneFlow Ingestion

> **Purpose**: Managed data ingestion from databases (CDC), Kafka streams, and cloud storage into lakehouse tables
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

OneFlow is the ingestion layer of Onehouse that delivers managed, low-latency data movement into Apache Hudi, Apache Iceberg, and Delta Lake tables. It supports three source categories: database CDC (PostgreSQL, MySQL, SQL Server, MongoDB), event streaming (Apache Kafka), and cloud storage file monitoring (S3/GCS with Avro, CSV, JSON, Parquet, Proto, XML). OneFlow operates on the principle of "ingest once, query anywhere" -- data lands in your storage once and is accessible through any engine via OneSync catalog synchronization.

## The Pattern

```text
Data Sources                    OneFlow Pipeline                  Lakehouse Tables
+------------------+           +-------------------+             +------------------+
| PostgreSQL (CDC) |--+        |                   |             | Hudi Tables      |
| MySQL (CDC)      |  |------->| Schema Discovery  |             | (Bronze Layer)   |
| SQL Server (CDC) |  |        | Schema Evolution  |   write     |                  |
| MongoDB (CDC)    |--+        | Data Quality      |------------>| Iceberg Tables   |
                               | Bad Record        |             | (via XTable)     |
+------------------+           | Quarantine        |             |                  |
| Kafka Streams    |---------->| Incremental       |   sync      | Delta Tables     |
+------------------+           | Processing        |------------>| (via XTable)     |
                               |                   |             |                  |
+------------------+           | Low-Code/No-Code  |             +------------------+
| S3/GCS Files     |---------->| Transformations   |                    |
| (Avro, CSV,      |           +-------------------+                    v
|  JSON, Parquet,  |                                             +------------------+
|  Proto, XML)     |                                             | OneSync Catalogs |
+------------------+                                             | (Snowflake, etc) |
                                                                 +------------------+
```

## Quick Reference

| Source Type | Supported Sources | Latency |
|-------------|-------------------|---------|
| Database CDC | PostgreSQL, MySQL, SQL Server, MongoDB | Minute-level |
| Event Streaming | Apache Kafka (all flavors, Confluent) | Near real-time |
| Cloud Files | S3, GCS (Avro, CSV, JSON, Parquet, Proto, XML) | Minutes |

| Feature | Description |
|---------|-------------|
| Schema Evolution | Automatic handling of source schema changes |
| Data Quality | Validation with bad record quarantine |
| Auto-Discovery | Monitors sources for structural changes |
| Incremental Processing | Only processes changed data, not full reloads |
| Low-Code Transforms | UI-based transformations with schema preview |
| Custom Code | Deploy custom transformation logic in customer VPC |

## Common Mistakes

### Wrong

```text
Creating separate ingestion pipelines for each query engine
(one for Snowflake, one for Databricks, one for BigQuery).
```

### Correct

```text
Ingest once with OneFlow into Hudi tables in your cloud storage.
Use OneSync to expose the same data to all engines simultaneously.
XTable translates Hudi metadata to Iceberg/Delta as needed.
```

## Related

- [Platform Architecture](../concepts/platform-architecture.md)
- [OneSync Catalog](../concepts/onesync-catalog.md)
- [CDC Ingestion Pipeline](../patterns/cdc-ingestion-pipeline.md)
- [Incremental ETL](../patterns/incremental-etl.md)
