# Schema Evolution

> **Purpose**: Add, drop, rename, reorder, and widen columns without rewriting data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Iceberg supports **full schema evolution** — adding, dropping, renaming, reordering, and widening columns — without rewriting existing data files. This is possible because Iceberg uses **column IDs** (not names or positions) to map schema fields to data file columns. Old data files are read with the schema that was active when they were written, and results are projected to the current schema.

## The Pattern

```sql
-- Add a column
ALTER TABLE prod.db.events ADD COLUMNS (
  user_agent STRING COMMENT 'Browser user agent'
);

-- Add nested column to a struct
ALTER TABLE prod.db.events ADD COLUMNS (
  location.zip STRING
);

-- Drop a column
ALTER TABLE prod.db.events DROP COLUMN user_agent;

-- Rename a column
ALTER TABLE prod.db.events RENAME COLUMN old_name TO new_name;

-- Reorder columns
ALTER TABLE prod.db.events ALTER COLUMN event_type AFTER event_id;

-- Move column to first position
ALTER TABLE prod.db.events ALTER COLUMN event_id FIRST;

-- Widen type (int → bigint, float → double)
ALTER TABLE prod.db.events ALTER COLUMN event_count TYPE bigint;
```

## Supported Type Promotions

| From | To | Safe? |
|------|----|:-----:|
| `int` | `long` | Yes |
| `float` | `double` | Yes |
| `decimal(P,S)` | `decimal(P2,S)` where P2 > P | Yes |
| `string` | `int` | No |
| `long` | `int` | No (narrowing) |

## How It Works: Column IDs

```text
Schema v1:                    Schema v2 (after rename + add):
  id: 1  (int, "user_id")      id: 1  (int, "customer_id")  ← renamed
  id: 2  (string, "name")      id: 2  (string, "name")
  id: 3  (long, "ts")          id: 3  (long, "ts")
                                id: 4  (string, "email")     ← added

Data file written with v1:
  Parquet columns: [field_id=1, field_id=2, field_id=3]

Reading with v2:
  field_id=1 → customer_id (was user_id, same data)
  field_id=2 → name
  field_id=3 → ts
  field_id=4 → email (NULL for old files — column didn't exist)
```

Column IDs are stored in **Parquet field metadata**, not file paths or column positions. This is why renames and reorders are free.

## New in Spec v3 (2025)

### Default Column Values (1.8.0)

Columns can now have default values. When adding a column with a default, old files return the default instead of NULL:

```sql
ALTER TABLE t ADD COLUMNS (status STRING DEFAULT 'active');
-- Old files return 'active' instead of NULL for this column
```

### Variant Type (1.9.0)

New semi-structured data type for JSON-like data. Replaces storing JSON as strings:

```sql
ALTER TABLE t ADD COLUMNS (metadata VARIANT);
-- Query nested fields directly without parsing
```

### Nanosecond Timestamps (1.9.0)

`timestamptz_ns` and `timestamp_ns` types for sub-microsecond precision.

## Quick Reference

| Operation | Rewrites Data? | Notes |
|-----------|:--------------:|-------|
| Add column | No | New column is NULL in old files (or default value in v3) |
| Drop column | No | Column ignored in reads |
| Rename column | No | ID-based mapping |
| Reorder column | No | ID-based mapping |
| Widen type | No | Promotion at read time |
| Change nullability (required → optional) | No | Safe direction only |
| Add required column | Not allowed | Would violate existing data |
| Add column with default (v3) | No | Old files return default value |

## Common Mistakes

### Wrong

```sql
-- Trying to add a non-nullable column
ALTER TABLE t ADD COLUMNS (status STRING NOT NULL);
-- ERROR: Cannot add a required (non-null) column to an existing table
```

### Correct

```sql
-- Add as nullable, then backfill if needed
ALTER TABLE t ADD COLUMNS (status STRING);

-- Backfill with MERGE INTO or UPDATE
UPDATE t SET status = 'active' WHERE status IS NULL;
```

## Related

- [Table Format](../concepts/table-format.md) — how schemas are stored in metadata
- [Partitioning](../concepts/partitioning.md) — partition spec evolution
- [Spark Integration](../patterns/spark-integration.md) — DDL commands in Spark
