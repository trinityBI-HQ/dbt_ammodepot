# Migration from Hive Tables

> **Purpose**: Migrate existing Hive tables to Iceberg with minimal disruption
> **MCP Validated**: 2026-02-19

## When to Use

- Modernizing a Hive-based data lake to lakehouse architecture
- Need schema/partition evolution on existing tables
- Want time travel and ACID on existing data
- Migrating to multi-engine access (Spark + Trino + Flink)

## Migration Strategies

| Strategy | Data Rewrite? | Downtime | Data Files |
|----------|:------------:|:--------:|------------|
| **In-place migration** | No | Minimal | Reuses existing Parquet/ORC |
| **Snapshot migration** | No | None | Creates Iceberg metadata over existing files |
| **Full rewrite** | Yes | Yes | Creates new optimized Iceberg files |

## In-Place Migration (Recommended)

Converts a Hive table to Iceberg **without rewriting data files**. The fastest approach — creates Iceberg metadata that references existing Parquet/ORC files.

```sql
-- Migrate Hive table to Iceberg in-place
CALL my_catalog.system.migrate('db.hive_events');
```

### What happens:
1. Iceberg reads the Hive table's metadata (schema, partitions, file listing)
2. Creates manifest files tracking all existing data files
3. Creates Iceberg metadata (metadata.json, manifest list)
4. Updates the catalog entry to point to Iceberg metadata
5. Original data files are **not moved or copied**

### Migrate with properties:

```sql
CALL my_catalog.system.migrate(
  table => 'db.hive_events',
  properties => map(
    'write.parquet.compression-codec', 'zstd',
    'write.target-file-size-bytes', '536870912'
  )
);
```

## Snapshot Migration (Zero Downtime)

Creates an Iceberg table that references the Hive table's data at a point in time. The Hive table continues to work — both exist simultaneously.

```sql
-- Create Iceberg snapshot of Hive table
CALL my_catalog.system.snapshot('db.hive_events', 'db.iceberg_events');

-- With custom properties
CALL my_catalog.system.snapshot(
  source_table => 'db.hive_events',
  table => 'db.iceberg_events',
  properties => map('write.parquet.compression-codec', 'zstd')
);
```

### Use case: Gradual migration

```text
1. snapshot() → Create Iceberg copy
2. Validate queries match between Hive and Iceberg
3. Redirect readers to Iceberg table
4. Redirect writers to Iceberg table
5. Drop Hive table when no longer needed
```

## Full Rewrite (CTAS)

Rewrites all data into optimized Iceberg files. Best for applying new partitioning or sort order.

```sql
-- Create new Iceberg table from Hive
CREATE TABLE my_catalog.db.events_v2
USING iceberg
PARTITIONED BY (day(event_time))
TBLPROPERTIES ('write.sort-order' = 'user_id ASC')
AS SELECT * FROM hive_catalog.db.events;
```

## Post-Migration Steps

### 1. Verify Data

```sql
-- Compare row counts
SELECT COUNT(*) FROM my_catalog.db.iceberg_events;
SELECT COUNT(*) FROM hive_catalog.db.hive_events;

-- Spot-check sample data
SELECT * FROM my_catalog.db.iceberg_events LIMIT 100;
```

### 2. Apply Schema Evolution (if needed)

```sql
-- Rename poorly named columns
ALTER TABLE my_catalog.db.iceberg_events RENAME COLUMN dt TO event_date;

-- Add new columns
ALTER TABLE my_catalog.db.iceberg_events ADD COLUMNS (source STRING);
```

### 3. Evolve Partitioning

```sql
-- Switch from Hive-style string partitions to Iceberg transforms
ALTER TABLE my_catalog.db.iceberg_events
  REPLACE PARTITION FIELD dt WITH day(event_time);
```

### 4. Run Initial Compaction

```sql
-- Hive files may be suboptimal sizes
CALL my_catalog.system.rewrite_data_files(
  table => 'db.iceberg_events',
  strategy => 'sort',
  sort_order => 'user_id ASC, event_time DESC'
);
```

## Rollback Migration

If migration fails, you can revert an in-place migration:

```sql
-- Revert back to Hive table (in-place migration only)
CALL my_catalog.system.rollback_to_version('db.events', 'hive');
```

For snapshot migration, simply drop the Iceberg table — original Hive table is untouched.

## Common Mistakes

| Don't | Do |
|-------|-----|
| Migrate and switch all readers at once | Use snapshot migration for gradual cutover |
| Skip data validation after migration | Compare row counts and sample data |
| Forget to compact after migration | Run `rewrite_data_files` for optimal file sizes |
| Migrate without testing rollback | Test `rollback_to_version` before production migration |

## See Also

- [Spark Integration](../patterns/spark-integration.md) — Spark config for Iceberg
- [Table Maintenance](../patterns/table-maintenance.md) — post-migration compaction
- [Partitioning](../concepts/partitioning.md) — hidden partitioning after migration
