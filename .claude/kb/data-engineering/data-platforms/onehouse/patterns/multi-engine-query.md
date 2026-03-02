# Multi-Engine Query Pattern

> **Purpose**: Write data once with Apache Hudi and query from Snowflake, Databricks, BigQuery, and other engines via XTable and OneSync
> **MCP Validated**: 2026-03-01

## When to Use

- Organization uses multiple query engines (e.g., Snowflake for BI, Databricks for ML)
- Want to avoid data duplication across platforms and formats
- Need to prevent vendor lock-in while maintaining engine-specific optimizations
- Building a shared data platform where different teams use different tools
- Migrating between engines without rewriting ingestion pipelines

## Implementation

```text
Multi-Engine Query Architecture
================================

1. WRITE LAYER (OneFlow + Hudi)
   Data sources --> OneFlow --> Hudi tables in S3/GCS
   (Single write path, single copy of data)

2. FORMAT TRANSLATION (Apache XTable)
   Hudi metadata --> XTable sync --> Iceberg metadata
                                 --> Delta Lake metadata
   (Same Parquet files, multiple metadata layers)

3. CATALOG REGISTRATION (OneSync)
   Table metadata --> Snowflake Catalog (Iceberg)
                  --> Unity Catalog (Delta/Iceberg)
                  --> Google Data Catalog (Iceberg)
                  --> AWS Glue (Hudi/Iceberg)
                  --> Hive Metastore (all formats)

4. QUERY LAYER (Any Engine)
   Snowflake SQL  -->  reads Iceberg metadata  --> Parquet files
   Databricks SQL -->  reads Delta metadata    --> Parquet files
   BigQuery SQL   -->  reads Iceberg metadata  --> Parquet files
   Athena SQL     -->  reads Hudi metadata     --> Parquet files
   Trino SQL      -->  reads any format        --> Parquet files

Why Hudi as Write Format?
  - Record-level index for fast upserts (10x faster)
  - Native CDC support with Merge-on-Read
  - Incremental query for efficient downstream processing
  - XTable translates to Iceberg/Delta for read engines
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `source_format` | `hudi` | Write format (Hudi recommended for CDC/upserts) |
| `target_formats` | `[iceberg, delta]` | Formats to generate via XTable |
| `catalog_targets` | `[]` | Catalogs to sync (Snowflake, Unity, Glue, etc.) |
| `sync_mode` | `incremental` | Sync only new commits (vs. full re-sync) |
| `schema_sync` | `auto` | Propagate schema changes to all catalogs |

## Example Usage

```text
Scenario: Unified Analytics + ML Platform
==========================================

Team A (BI Analysts): Uses Snowflake for dashboards
Team B (Data Scientists): Uses Databricks for ML training
Team C (Ad-hoc Queries): Uses Athena for cost-effective exploration

Setup:
  1. OneFlow ingests from PostgreSQL, MySQL, Kafka
  2. Data lands as Hudi MoR tables in s3://lakehouse/
  3. XTable generates Iceberg + Delta metadata
  4. OneSync registers tables in:
     - Snowflake Catalog (Team A reads Iceberg)
     - Databricks Unity (Team B reads Delta)
     - AWS Glue (Team C reads via Athena)

Benefits:
  - Single ingestion pipeline, single storage cost
  - Each team uses their preferred engine natively
  - Schema changes propagate automatically to all engines
  - No ETL jobs copying data between platforms
  - Switch or add engines without re-ingestion

Cost Impact:
  - Storage: 1x (single copy of Parquet files)
  - Ingestion compute: 1x (single OneFlow pipeline)
  - Metadata overhead: ~1-3% additional storage for extra formats
```

## See Also

- [XTable Interoperability](../concepts/xtable-interoperability.md)
- [OneSync Catalog](../concepts/onesync-catalog.md)
- [CDC Ingestion Pipeline](../patterns/cdc-ingestion-pipeline.md)
