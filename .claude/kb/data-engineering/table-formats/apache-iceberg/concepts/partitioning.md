# Hidden Partitioning & Partition Evolution

> **Purpose**: Understand Iceberg's partition transforms and how to evolve partitions without rewriting data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Iceberg uses **hidden partitioning** — partition values are derived from source columns using transforms, and users never interact with partition columns directly. Queries filter on source columns (`WHERE ts > '2026-01-01'`), and Iceberg automatically applies partition pruning. This eliminates the "wrong partition column" class of bugs that plague Hive-style partitioning.

## Hive vs Iceberg Partitioning

### Hive (Problematic)

```sql
-- User must maintain a separate partition column
CREATE TABLE events (id BIGINT, data STRING, ts TIMESTAMP, day STRING)
PARTITIONED BY (day);

-- User must filter on the partition column, NOT the source column
SELECT * FROM events WHERE day = '2026-02-12';  -- correct
SELECT * FROM events WHERE ts > '2026-02-12';   -- FULL TABLE SCAN!
```

### Iceberg (Correct)

```sql
-- Partition derived from source column via transform
CREATE TABLE prod.db.events (
  id BIGINT,
  data STRING,
  ts TIMESTAMP
) USING iceberg
PARTITIONED BY (day(ts));

-- User filters on source column — Iceberg handles pruning
SELECT * FROM prod.db.events WHERE ts > '2026-02-12 00:00:00';
-- Iceberg automatically prunes to partitions where day(ts) >= '2026-02-12'
```

## Partition Transforms

| Transform | Syntax | Source Type | Output | Example |
|-----------|--------|-------------|--------|---------|
| Identity | `col` | Any | Same value | `country` → `US` |
| Year | `year(col)` | Timestamp/Date | Integer year | `2026` |
| Month | `month(col)` | Timestamp/Date | Year-month | `2026-02` |
| Day | `day(col)` | Timestamp/Date | Year-month-day | `2026-02-12` |
| Hour | `hour(col)` | Timestamp/Date | Year-month-day-hour | `2026-02-12-14` |
| Bucket | `bucket(N, col)` | Any | Hash mod N | `bucket(16, id)` → `7` |
| Truncate | `truncate(W, col)` | String/Int | Truncated value | `truncate(3, city)` → `New` |

**v3 (1.10.0)**: Multi-argument partition transforms allow transforms that take multiple columns or parameters, enabling more expressive partitioning strategies.

## Partition Evolution

Iceberg can **change the partition strategy** without rewriting data. Old data keeps its old layout; new data uses the new layout. Query planning handles both transparently.

```sql
-- Start with daily partitioning
CREATE TABLE prod.db.events (id BIGINT, ts TIMESTAMP, data STRING)
USING iceberg
PARTITIONED BY (day(ts));

-- After data grows, switch to hourly for better pruning
ALTER TABLE prod.db.events REPLACE PARTITION FIELD day(ts) WITH hour(ts);
```

```text
After evolution:
  Old data files: partitioned by day(ts) — NOT rewritten
  New data files: partitioned by hour(ts)
  Queries: Iceberg plans across both layouts correctly
```

### Adding Partition Fields

```sql
-- Add a bucket partition for high-cardinality joins
ALTER TABLE prod.db.events ADD PARTITION FIELD bucket(16, id);

-- Drop a partition field (existing data unchanged)
ALTER TABLE prod.db.events DROP PARTITION FIELD day(ts);
```

## Multi-Dimensional Partitioning

```sql
-- Partition by both time and a hash bucket
CREATE TABLE prod.db.events (
  id BIGINT,
  ts TIMESTAMP,
  data STRING
) USING iceberg
PARTITIONED BY (day(ts), bucket(8, id));
```

This creates partition combinations like `day=2026-02-12/bucket=3`, enabling pruning on both time ranges and specific IDs.

## Common Mistakes

### Wrong

```sql
-- Hive-style: creating a separate partition column
CREATE TABLE t (id BIGINT, ts TIMESTAMP, day STRING)
USING iceberg PARTITIONED BY (day);
-- Redundant column, manual maintenance, error-prone
```

### Correct

```sql
-- Iceberg-style: derive partition from source column
CREATE TABLE t (id BIGINT, ts TIMESTAMP)
USING iceberg PARTITIONED BY (day(ts));
-- Automatic, correct pruning on ts queries
```

## Related

- [Schema Evolution](../concepts/schema-evolution.md) — schema changes alongside partition changes
- [Performance Tuning](../patterns/performance-tuning.md) — partition strategy for query optimization
- [Table Format](../concepts/table-format.md) — how partition specs are stored in metadata
