# Performance Tuning

> **Purpose**: Optimize Iceberg query and write performance with sorting, pruning, and configuration
> **MCP Validated**: 2026-02-19

## When to Use

- Queries scanning too many files (slow reads)
- Small file problem from streaming or frequent writes
- Need to optimize for specific query patterns
- Reducing storage and compute costs

## File Pruning (Min/Max Statistics)

Iceberg stores column-level min/max stats in manifest entries. Queries use these to skip entire data files that cannot match the predicate.

```text
Manifest entry for data-file-0001.parquet:
  lower_bounds: {user_id: 1, ts: '2026-02-01'}
  upper_bounds: {user_id: 500, ts: '2026-02-12'}

Query: WHERE user_id = 750
  → Skip this file (750 > 500)

Query: WHERE ts = '2026-01-15'
  → Skip this file ('2026-01-15' < '2026-02-01')
```

Pruning effectiveness depends on how well data is **sorted** within files.

## Sorted Writes

### Table-Level Sort Order

```sql
-- Set default write sort order
CREATE TABLE prod.db.events (
    event_id BIGINT, user_id BIGINT, ts TIMESTAMP, data STRING
) USING iceberg
PARTITIONED BY (day(ts))
TBLPROPERTIES ('write.sort-order' = 'user_id ASC');

-- Update sort order for existing table
ALTER TABLE prod.db.events WRITE ORDERED BY user_id ASC, ts DESC;
```

Spark automatically sorts data before writing when a sort order is configured.

### Write Distribution Mode

| Mode | Behavior | Use Case |
|------|----------|----------|
| `none` | No redistribution | Fast writes, many small files |
| `hash` | Hash by partition key | Balanced partitions |
| `range` | Range by sort key | Globally sorted files |

```sql
ALTER TABLE prod.db.events SET TBLPROPERTIES (
  'write.distribution-mode' = 'range'
);
```

## Z-Order Sorting

For queries that filter on **multiple columns**, z-order interleaves column values to provide pruning on all sorted dimensions simultaneously.

```sql
-- Z-order compaction (best applied during maintenance)
CALL my_catalog.system.rewrite_data_files(
  table => 'db.events',
  strategy => 'sort',
  sort_order => 'zorder(user_id, event_type)'
);
```

### When to Use Z-Order

| Scenario | Strategy |
|----------|----------|
| Filter on 1 column mostly | Linear sort (`user_id ASC`) |
| Filter on 2-3 columns equally | Z-order (`zorder(col1, col2)`) |
| Filter on 4+ columns | Z-order less effective — consider partitioning |

## Partition Strategy

Choose partition granularity based on data volume and query patterns:

| Daily Data Volume | Partition Granularity | Why |
|-------------------|----------------------|-----|
| < 100 MB | `month(ts)` or `year(ts)` | Avoid too many small partitions |
| 100 MB – 10 GB | `day(ts)` | Good balance |
| 10 GB – 1 TB | `day(ts)` + `bucket(N, id)` | Multi-dimensional pruning |
| > 1 TB | `hour(ts)` + `bucket(N, id)` | Fine-grained pruning |

```sql
-- Right-sized partitioning for high-volume tables
CREATE TABLE prod.db.events (
  event_id BIGINT, user_id BIGINT, ts TIMESTAMP
) USING iceberg
PARTITIONED BY (day(ts), bucket(32, user_id));
```

## File Size Tuning

| Property | Default | Recommended | Notes |
|----------|---------|-------------|-------|
| `write.target-file-size-bytes` | 512 MB | 256-512 MB | Larger for less metadata, smaller for faster compaction |
| `read.split.target-size` | 128 MB | 128-256 MB | Match Spark executor memory |
| `write.parquet.row-group-size-bytes` | 128 MB | 128 MB | Usually fine at default |
| `write.parquet.compression-codec` | gzip | **zstd** | Better compression ratio + speed |

```sql
ALTER TABLE prod.db.events SET TBLPROPERTIES (
  'write.target-file-size-bytes' = '268435456',          -- 256 MB
  'write.parquet.compression-codec' = 'zstd',
  'write.parquet.compression-level' = '3'                 -- zstd level (1-22)
);
```

## Predicate Pushdown

Iceberg pushes predicates to Parquet's row group statistics for additional pruning within files:

```python
# These predicates push down efficiently
df = spark.table("prod.db.events") \
    .filter("ts >= '2026-02-01' AND ts < '2026-02-12'") \
    .filter("user_id = 42")

# This does NOT push down (complex expressions)
df = spark.table("prod.db.events") \
    .filter("UPPER(event_type) = 'CLICK'")  # function prevents pushdown
```

**Pushdown-friendly predicates:** `=`, `<`, `>`, `<=`, `>=`, `IN`, `IS NULL`, `IS NOT NULL`, `BETWEEN`

## Deletion Vectors for Write Performance (v3)

For tables with frequent UPDATE/DELETE/MERGE INTO, enable merge-on-read with deletion vectors to avoid rewriting entire data files:

```sql
ALTER TABLE prod.db.events SET TBLPROPERTIES (
  'write.delete.mode' = 'merge-on-read',
  'write.update.mode' = 'merge-on-read'
);
-- Writes are faster (bitmap only), reads slightly slower until compaction
```

## Monitoring Performance

```sql
-- Check file sizes and counts per partition
SELECT partition, file_count, total_record_count,
       total_file_size_in_bytes / file_count AS avg_file_size
FROM prod.db.events.partitions;

-- Check manifest file counts
SELECT * FROM prod.db.events.manifests;

-- Check for small files
SELECT file_path, file_size_in_bytes, record_count
FROM prod.db.events.files
WHERE file_size_in_bytes < 67108864  -- files under 64 MB
ORDER BY file_size_in_bytes;
```

## See Also

- [Table Maintenance](../patterns/table-maintenance.md) — compaction procedures
- [Partitioning](../concepts/partitioning.md) — partition transforms
- [Spark Integration](../patterns/spark-integration.md) — write configuration
