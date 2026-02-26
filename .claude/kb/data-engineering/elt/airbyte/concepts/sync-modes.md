# Sync Modes

> **Purpose**: Strategies for reading data from sources and writing to destinations
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A sync mode governs how Airbyte reads data from a source and writes it to a destination. The mode combines a **source mode** (how to read) with a **destination mode** (how to write). Choosing the right sync mode is critical for efficiency, cost, and data freshness. Airbyte supports four primary combinations: Full Refresh Overwrite, Full Refresh Append, Incremental Append, and Incremental Append + Deduped.

**Airbyte 2.0 (Oct 2025)**: The new sync engine delivers **4-6x faster syncs** across all modes, with the Snowflake destination running **10x faster at 95% lower cost**.

## The Pattern

```yaml
# Connection configuration
streams:
  - stream_name: orders
    sync_mode: incremental_append_deduped
    cursor_field: [updated_at]
    primary_key: [order_id]

  - stream_name: products
    sync_mode: full_refresh_overwrite
```

## Quick Reference

| Sync Mode | Reads | Writes | Data Volume | Use Case |
|-----------|-------|--------|-------------|----------|
| Full Refresh Overwrite | All records | Replace table | High | Small tables, schema changes |
| Full Refresh Append | All records | Append | High | Audit trail, snapshots |
| Incremental Append | New/changed only | Append | Low | Event streams |
| Incremental Append + Deduped | New/changed only | Append + dedupe | Low | Mutable records, CDC |

## Source Modes

### Full Refresh

Reads all available records from the source on every sync, regardless of previous syncs.

**When to use:**
- Small tables (< 10K rows)
- Tables without reliable update timestamps
- Schema changes detected
- Reference/dimension tables that change infrequently

**Cost:** High (reads entire dataset every time)

### Incremental

Reads only new or updated records since the last sync using a **cursor field** (timestamp or auto-incrementing ID).

**When to use:**
- Large tables (> 100K rows)
- Tables with `updated_at` or `created_at` columns
- Event logs or time-series data
- Cost-sensitive workloads

**Requirements:**
- Cursor field must exist (timestamp, sequential ID)
- Cursor field must increase monotonically
- Source must support filtering by cursor

```sql
-- What incremental sync does
SELECT * FROM orders
WHERE updated_at > '2024-12-01 10:00:00'  -- Last sync timestamp
```

## Destination Modes

### Overwrite

Deletes all existing data in the destination table and replaces it with data from the current sync.

**Data loss risk:** Previous data is destroyed.

### Append

Adds new records to the destination table without deleting existing records.

**Result:** Historical snapshots of all syncs.

```sql
-- Destination table after 3 syncs
| id | name    | updated_at | _airbyte_extracted_at |
|----|---------|------------|----------------------|
| 1  | Alice   | 2024-01-01 | 2024-01-01 08:00     |
| 1  | Alice   | 2024-01-02 | 2024-01-02 08:00     |
| 1  | Alice B | 2024-01-03 | 2024-01-03 08:00     |
```

### Append + Deduped

Appends new records to a raw table (`_airbyte_raw_<stream>`) and maintains a **deduped view** showing only the latest version of each record.

**Implementation:** Uses dbt-based typing and deduping.

```sql
-- Deduped view (SCD Type 2)
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) as rn
  FROM raw_table
) WHERE rn = 1
```

## Sync Mode Combinations

### 1. Full Refresh Overwrite

```yaml
source_mode: full_refresh
destination_mode: overwrite
result: Latest snapshot only
```

**Example:** Daily snapshot of product catalog

| Pros | Cons |
|------|------|
| Simple, no cursors needed | Reads all data every sync |
| Handles schema changes | High API/database load |
| Clean destination | Loses historical changes |

### 2. Full Refresh Append

```yaml
source_mode: full_refresh
destination_mode: append
result: Historical snapshots
```

**Example:** Daily inventory counts for trend analysis

| Pros | Cons |
|------|------|
| Keep historical snapshots | Reads all data every sync |
| Audit trail | Storage grows quickly |

### 3. Incremental Append

```yaml
source_mode: incremental
destination_mode: append
cursor_field: created_at
result: All events/records
```

**Example:** Application event logs, immutable records

| Pros | Cons |
|------|------|
| Efficient (only new data) | Duplicate records if updated |
| Low cost | No deduplication |

### 4. Incremental Append + Deduped

```yaml
source_mode: incremental
destination_mode: append_deduped
cursor_field: updated_at
primary_key: [id]
result: Latest + history
```

**Example:** Customer records that change over time

| Pros | Cons |
|------|------|
| Efficient + accurate | Requires normalization |
| SCD Type 2 history | Additional compute cost |
| Handles updates | Complexity |

## Cursor Field Selection

| Field Type | Suitability | Notes |
|------------|-------------|-------|
| `updated_at` | Excellent | Best for mutable records |
| `created_at` | Good | For append-only data |
| Auto-increment ID | Good | Monotonic, reliable |
| Modified timestamp | Excellent | Standard pattern |
| UUID | Poor | Non-sequential |

## Common Mistakes

### Wrong

```yaml
# Anti-pattern: Full refresh for large table
streams:
  - stream_name: transactions  # 100M rows
    sync_mode: full_refresh_overwrite  # Reads 100M rows every hour!
```

### Correct

```yaml
# Correct: Incremental for large table
streams:
  - stream_name: transactions
    sync_mode: incremental_append_deduped
    cursor_field: [updated_at]
    primary_key: [transaction_id]
```

## Related

- [connectors](../concepts/connectors.md)
- [connections](../concepts/connections.md)
- [normalization](../concepts/normalization.md)
- [incremental-dedup-pattern](../patterns/incremental-dedup-pattern.md)
