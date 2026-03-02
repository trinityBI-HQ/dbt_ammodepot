# Incremental ETL Pattern

> **Purpose**: Bronze-to-silver lakehouse transformations using Onehouse managed incremental processing pipelines
> **MCP Validated**: 2026-03-01

## When to Use

- Transforming raw ingested data (bronze) into cleaned, enriched datasets (silver)
- Need incremental processing that only transforms new/changed records
- Want low-code or no-code transformations without managing Spark infrastructure
- Building medallion architecture (Bronze -> Silver -> Gold) on the lakehouse
- Replacing full-table-scan ETL jobs with change-aware incremental pipelines

## Implementation

```text
Incremental ETL Pipeline Architecture
=======================================

Bronze Layer (Raw Ingestion via OneFlow)
+----------------------------------------------+
| Hudi MoR Tables (CDC from sources)           |
| - Raw columns as-is from source              |
| - _hoodie_commit_time for change tracking    |
| - Partitioned by ingestion date              |
+----------------------------------------------+
              |
              | Incremental query: only new commits
              v
Transformation Layer (Onehouse Managed)
+----------------------------------------------+
| Low-Code / No-Code Transformations           |
| - Column rename and type casting             |
| - Null handling and default values           |
| - Deduplication by record key                |
| - Filtering (remove soft-deleted records)    |
| - Joins with reference/dimension tables      |
| - Custom code (user-defined transforms)      |
+----------------------------------------------+
              |
              | Write incrementally to silver tables
              v
Silver Layer (Cleaned, Enriched)
+----------------------------------------------+
| Hudi CoW or MoR Tables                       |
| - Clean column names (snake_case)            |
| - Proper data types                          |
| - Deduplicated, null-handled                 |
| - Ready for Gold layer aggregation           |
+----------------------------------------------+
              |
              | OneSync to catalogs
              v
Query Engines (Snowflake, Databricks, BigQuery)


Key Principle: INCREMENTAL PROCESSING
======================================
Traditional ETL:
  Read ALL bronze records --> Transform --> Write ALL to silver
  Cost: O(total_records) every run

Onehouse Incremental ETL:
  Read ONLY NEW commits from bronze --> Transform --> Upsert to silver
  Cost: O(new_records) per run

  Hudi's commit timeline tracks exactly which records changed,
  enabling efficient incremental reads without scanning all data.
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `source_table` | (required) | Bronze Hudi table path |
| `target_table` | (required) | Silver table output path |
| `processing_mode` | `incremental` | `incremental` or `snapshot` (full reload) |
| `transform_type` | `low_code` | `low_code` (UI), `sql`, or `custom` (user code) |
| `dedup_key` | Primary key | Column(s) for deduplication |
| `partition_key` | Date column | Silver table partitioning column |
| `target_table_type` | `COPY_ON_WRITE` | CoW (read-heavy silver) or MoR |
| `schedule` | `continuous` | `continuous`, `cron`, or `trigger` |

## Example Usage

```text
Scenario: Medallion Architecture for Sales Data
================================================

Bronze (OneFlow CDC ingestion):
  Source: PostgreSQL sales_orders table
  Table: s3://lakehouse/bronze/sales_orders/ (Hudi MoR)
  Freshness: < 2 minutes from source

Silver (Onehouse Incremental ETL):
  Transformations:
    - Rename: order_id --> sales_order_id
    - Cast: created_at (varchar) --> order_timestamp (timestamp)
    - Filter: WHERE _hoodie_is_deleted = false
    - Dedup: By sales_order_id (keep latest)
    - Enrich: Join with dim_store for store_name
  Table: s3://lakehouse/silver/sales_orders/ (Hudi CoW)
  Processing: Incremental (only new commits from bronze)

Gold (downstream dbt or Spark):
  Aggregation and business logic on top of silver tables
  Consumed by BI dashboards via Snowflake/Databricks

Benefits:
  - Bronze ingestion and silver transformation run independently
  - Silver only processes changed records (not full table scans)
  - Schema changes in bronze auto-propagate to silver
  - No Spark cluster management (OCR handles compute)
```

## See Also

- [OneFlow Ingestion](../concepts/oneflow-ingestion.md)
- [CDC Ingestion Pipeline](../patterns/cdc-ingestion-pipeline.md)
- [Table Optimization](../patterns/table-optimization.md)
