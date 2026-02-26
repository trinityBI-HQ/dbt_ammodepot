# Apache Iceberg Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Format Spec v3 Features (2025)

| Feature | Version | Description |
|---------|---------|-------------|
| Deletion vectors | 1.8.0 | Binary bitmaps marking deleted rows without rewriting files |
| Default column values | 1.8.0 | Default values for new columns (avoids NULL backfill) |
| Row-level lineage | 1.8.0 | Track which rows came from which source |
| `variant` type | 1.9.0 | Semi-structured data type (JSON-like) |
| Geospatial types | 1.9.0 | Native geometry/geography types |
| Nanosecond timestamps | 1.9.0 | Sub-microsecond precision |
| Multi-argument transforms | 1.10.0 | Partition transforms with multiple args |
| v3 spec stability | 1.10.0 | Format v3 considered stable |

## Spark Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `spark.sql.extensions` | `org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions` | Enable SQL extensions |
| `spark.sql.catalog.<name>` | `org.apache.iceberg.spark.SparkCatalog` | Register Iceberg catalog |
| `spark.sql.catalog.<name>.type` | `hive` / `hadoop` / `rest` / `glue` / `nessie` | Catalog backend |
| `spark.sql.catalog.<name>.warehouse` | `s3://bucket/warehouse` | Storage location |
| `spark.sql.defaultCatalog` | `<name>` | Set default catalog |

## Partition Transforms

| Transform | SQL | Example Output |
|-----------|-----|----------------|
| `identity` | `PARTITIONED BY (col)` | Exact value |
| `year` | `PARTITIONED BY (year(ts))` | `2026` |
| `month` | `PARTITIONED BY (month(ts))` | `2026-02` |
| `day` | `PARTITIONED BY (day(ts))` | `2026-02-12` |
| `hour` | `PARTITIONED BY (hour(ts))` | `2026-02-12-14` |
| `bucket(N)` | `PARTITIONED BY (bucket(16, id))` | Hash mod N |
| `truncate(W)` | `PARTITIONED BY (truncate(10, name))` | First W chars |

## Schema Evolution Operations

| Operation | SQL | Requires Rewrite? |
|-----------|-----|:-----------------:|
| Add column | `ALTER TABLE t ADD COLUMNS (col type)` | No |
| Drop column | `ALTER TABLE t DROP COLUMN col` | No |
| Rename column | `ALTER TABLE t RENAME COLUMN old TO new` | No |
| Reorder column | `ALTER TABLE t ALTER COLUMN col AFTER other` | No |
| Widen type | `ALTER TABLE t ALTER COLUMN col TYPE bigint` | No |
| Add required column | Not allowed (nullable only) | N/A |

## Key Procedures (Spark)

| Procedure | Purpose |
|-----------|---------|
| `rewrite_data_files` | Compact small files (bin-pack or sort/z-order) |
| `rewrite_manifests` | Rewrite manifest files for better planning |
| `expire_snapshots` | Remove old snapshots and unreferenced data files |
| `remove_orphan_files` | Delete files not tracked by any snapshot |
| `rollback_to_snapshot` | Revert table to a previous snapshot |
| `rollback_to_timestamp` | Revert table to state at a timestamp |
| `set_current_snapshot` | Cherry-pick a specific snapshot |
| `fast_forward` | Fast-forward a branch to another ref |

## Time Travel Syntax

| Method | SQL |
|--------|-----|
| Snapshot ID | `SELECT * FROM t VERSION AS OF 123456` |
| Timestamp | `SELECT * FROM t TIMESTAMP AS OF '2026-01-01 00:00:00'` |
| Branch | `SELECT * FROM t VERSION AS OF 'audit-branch'` |
| Tag | `SELECT * FROM t VERSION AS OF 'release-v1'` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Multi-engine (Spark + Trino + Flink) | **Iceberg** |
| Databricks-only lakehouse | Delta Lake |
| Near-real-time record-level upserts | Hudi |
| Vendor-neutral open standard | **Iceberg** |
| Need partition/schema evolution | **Iceberg** |
| Existing Hive tables to modernize | **Iceberg** (in-place migration) |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use Hive-style `PARTITIONED BY (year STRING)` | Use transforms: `PARTITIONED BY (year(ts))` |
| Forget to run compaction on streaming tables | Schedule `rewrite_data_files` regularly |
| Let snapshots accumulate indefinitely | Run `expire_snapshots` with retention policy |
| Use `INSERT OVERWRITE` for upserts | Use `MERGE INTO` for row-level updates |
| Query by partition directory path | Query by source column — Iceberg handles pruning |
| Skip catalog configuration | Always configure a proper catalog (REST preferred) |

## Related

See `index.md` for full navigation and learning path.
