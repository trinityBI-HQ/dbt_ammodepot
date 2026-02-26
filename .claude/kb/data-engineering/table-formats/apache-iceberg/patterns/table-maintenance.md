# Table Maintenance

> **Purpose**: Compaction, snapshot expiry, orphan file cleanup, and manifest rewriting
> **MCP Validated**: 2026-02-19

## When to Use

- Small files accumulating from streaming or frequent inserts
- Metadata growing large (slow query planning)
- Storage costs increasing from unreferenced data files
- Snapshots accumulating beyond retention needs

## Compaction (rewrite_data_files)

Compacts small files into larger ones. Essential for tables with streaming writes or frequent small appends.

### Bin-Pack (Default)

Combines small files without sorting:

```sql
-- Basic compaction
CALL my_catalog.system.rewrite_data_files('db.events');

-- With options
CALL my_catalog.system.rewrite_data_files(
  table => 'db.events',
  options => map(
    'target-file-size-bytes', '536870912',   -- 512 MB
    'min-file-size-bytes',    '67108864',    -- 64 MB (skip files above this)
    'max-file-size-bytes',    '805306368',   -- 768 MB
    'min-input-files',        '5',           -- need at least 5 files to compact
    'partial-progress.enabled', 'true',      -- commit progress incrementally
    'partial-progress.max-commits', '10'
  )
);

-- Compact only specific partitions
CALL my_catalog.system.rewrite_data_files(
  table => 'db.events',
  where => 'ts >= TIMESTAMP ''2026-02-01'' AND ts < TIMESTAMP ''2026-02-12'''
);
```

### Sort Compaction

Rewrites files sorted by columns for better pruning:

```sql
-- Sort by a column
CALL my_catalog.system.rewrite_data_files(
  table => 'db.events',
  strategy => 'sort',
  sort_order => 'event_type ASC NULLS LAST, ts DESC NULLS LAST'
);

-- Z-order for multi-dimensional pruning
CALL my_catalog.system.rewrite_data_files(
  table => 'db.events',
  strategy => 'sort',
  sort_order => 'zorder(user_id, ts)'
);
```

## Expire Snapshots

Removes old snapshots and their unreferenced data files. Critical for controlling storage costs.

```sql
-- Expire snapshots older than a timestamp
CALL my_catalog.system.expire_snapshots(
  table => 'db.events',
  older_than => TIMESTAMP '2026-02-01 00:00:00',
  retain_last => 5    -- keep at least 5 most recent
);
```

**Warning**: After expiring snapshots, time travel to those snapshots is no longer possible.

## Remove Orphan Files

Deletes data files not referenced by any snapshot (e.g., from failed writes):

```sql
CALL my_catalog.system.remove_orphan_files(
  table => 'db.events',
  older_than => TIMESTAMP '2026-02-09 00:00:00',
  dry_run => true    -- preview first!
);

-- Execute removal
CALL my_catalog.system.remove_orphan_files(
  table => 'db.events',
  older_than => TIMESTAMP '2026-02-09 00:00:00'
);
```

**Always run with `dry_run => true` first** to verify which files will be deleted.

## Rewrite Manifests

Optimizes manifest files for better query planning:

```sql
CALL my_catalog.system.rewrite_manifests('db.events');

-- With options
CALL my_catalog.system.rewrite_manifests(
  table => 'db.events',
  use_caching => true
);
```

## Deletion Vectors (v3, 1.8.0+)

Deletion vectors use **binary bitmaps** to mark deleted rows within data files without rewriting them. This is significantly faster than position delete files for row-level updates/deletes.

```sql
-- Enable deletion vectors for a table
ALTER TABLE db.events SET TBLPROPERTIES (
  'write.delete.mode' = 'merge-on-read',
  'write.update.mode' = 'merge-on-read'
);
```

Deletion vectors reduce write amplification for MERGE INTO and DELETE operations. Periodically compact to apply deletions and reclaim space.

## Recommended Maintenance Schedule

| Task | Frequency | Purpose |
|------|-----------|---------|
| `rewrite_data_files` (bin-pack) | Daily (streaming) / Weekly (batch) | Compact small files |
| `rewrite_data_files` (sort/z-order) | Weekly / Monthly | Optimize read performance |
| `expire_snapshots` | Daily | Control metadata + storage growth |
| `remove_orphan_files` | Weekly | Reclaim storage from failed writes |
| `rewrite_manifests` | Monthly | Optimize query planning |

## Automation with Dagster

```python
from dagster import asset, AssetExecutionContext

@asset(deps=["raw_events"])
def compact_events(context: AssetExecutionContext, spark):
    """Daily compaction of events table."""
    spark.sql("""
        CALL my_catalog.system.rewrite_data_files(
            table => 'db.events',
            options => map('min-input-files', '5')
        )
    """)
    spark.sql("""
        CALL my_catalog.system.expire_snapshots(
            table => 'db.events',
            older_than => current_timestamp() - INTERVAL 7 DAYS,
            retain_last => 10
        )
    """)
    context.log.info("Compaction and snapshot expiry complete")
```

## See Also

- [Performance Tuning](../patterns/performance-tuning.md) — sort/z-order strategy
- [Table Format](../concepts/table-format.md) — understanding manifest structure
- [Snapshots & Time Travel](../concepts/snapshots-time-travel.md) — snapshot retention impact
