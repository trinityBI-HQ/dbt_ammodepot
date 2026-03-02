# CDC Ingestion Pipeline

> **Purpose**: End-to-end change data capture from RDBMS to analytics-ready lakehouse tables with managed infrastructure
> **MCP Validated**: 2026-03-01

## When to Use

- Replicating operational databases (PostgreSQL, MySQL, SQL Server, MongoDB) to a data lakehouse
- Need minute-level data freshness for analytics without impacting source systems
- Want managed CDC that handles schema evolution, deletes, and upserts automatically
- Building a medallion architecture with real-time bronze layer from transactional databases
- Replacing self-managed Debezium/Kafka Connect CDC pipelines with a managed service

## Implementation

```text
CDC Ingestion Pipeline Architecture
====================================

Step 1: Configure Source Connection
------------------------------------
Source: PostgreSQL / MySQL / SQL Server / MongoDB
Connection: Host, port, database, credentials
Mode: CDC (Change Data Capture via WAL/binlog)
Tables: Select specific tables or full database

Step 2: Configure OneFlow Pipeline
------------------------------------
Pipeline Settings:
  - Source: Database connection (from Step 1)
  - Target: Cloud storage path (s3://bucket/bronze/)
  - Format: Apache Hudi (Merge-on-Read for write-heavy CDC)
  - Partitioning: Date-based or custom partition keys
  - Schema handling: Auto-evolve on source changes

Step 3: Configure Table Services
------------------------------------
Table Optimizer Settings:
  - Compaction: Every 30 minutes (for MoR tables)
  - Clustering: Daily, keyed on primary query columns
  - Cleaning: Daily, 72-hour retention window

Step 4: Configure Catalog Sync (OneSync)
------------------------------------
Catalogs:
  - Snowflake Catalog (Iceberg format)
  - AWS Glue (Hudi format)
  - Databricks Unity (Delta format)

Step 5: Monitor via LakeView
------------------------------------
Alerts:
  - Ingestion lag > 5 minutes
  - Compaction backlog > 10 pending jobs
  - Data skew ratio > 3:1
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `ingestion_mode` | `cdc` | CDC for change capture, `snapshot` for full loads |
| `table_type` | `MERGE_ON_READ` | MoR for write-heavy CDC, CoW for read-heavy |
| `compaction_frequency` | `30 min` | How often to compact MoR log files |
| `clustering_keys` | Primary key cols | Columns for data layout optimization |
| `retention_hours` | `72` | Time-travel window before cleaning |
| `schema_evolution` | `auto` | Automatic schema change handling |
| `bad_record_quarantine` | `enabled` | Isolate malformed records for review |
| `catalog_targets` | `[]` | List of catalogs for OneSync registration |

## Example Usage

```text
Use Case: E-commerce Order Replication
=======================================

Source: PostgreSQL (orders, order_items, customers, products)
Target: S3 Hudi tables partitioned by order_date
Latency: < 2 minutes end-to-end
Consumers: Snowflake (BI dashboards), Databricks (ML models)

Pipeline Flow:
  PostgreSQL WAL
    --> OneFlow CDC extractor
      --> Hudi MoR tables in s3://lakehouse/bronze/
        --> Table Optimizer (compaction every 30 min)
          --> OneSync to Snowflake Catalog (Iceberg)
          --> OneSync to Unity Catalog (Delta)

Result:
  - Snowflake: SELECT * FROM bronze.orders (reads Iceberg)
  - Databricks: SELECT * FROM bronze.orders (reads Delta)
  - Both read the SAME physical Parquet files
```

## See Also

- [OneFlow Ingestion](../concepts/oneflow-ingestion.md)
- [Table Optimization](../patterns/table-optimization.md)
- [Multi-Engine Query](../patterns/multi-engine-query.md)
