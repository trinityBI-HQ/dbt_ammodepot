# Sync Modes

> **Purpose**: Strategies for reading data from sources and writing to destinations
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A sync mode governs how Airbyte reads from a source and writes to a destination, combining a **source mode** (how to read) with a **destination mode** (how to write). Airbyte supports four primary combinations. **Airbyte 2.0 (Oct 2025)** delivers 4-6x faster syncs, with Snowflake destination running 10x faster at 95% lower cost.

## Quick Reference

| Sync Mode | Reads | Writes | Volume | Use Case |
|-----------|-------|--------|--------|----------|
| Full Refresh Overwrite | All | Replace | High | Small tables, schema changes |
| Full Refresh Append | All | Append | High | Audit trail, snapshots |
| Incremental Append | New/changed | Append | Low | Event streams |
| Incremental Append + Deduped | New/changed | Append + dedupe | Low | Mutable records, CDC |

## Source Modes

### Full Refresh
Reads all records every sync. Use for small tables (<10K rows), tables without reliable update timestamps, or reference/dimension tables. **Cost**: High.

### Incremental
Reads only new/updated records using a **cursor field** (timestamp or auto-incrementing ID). Use for large tables (>100K rows), tables with `updated_at`, event logs, or cost-sensitive workloads. Requires a monotonically increasing cursor field.

```sql
SELECT * FROM orders WHERE updated_at > '2024-12-01 10:00:00'  -- Last sync
```

## Destination Modes

**Overwrite**: Deletes existing data, replaces with current sync. Data loss risk.
**Append**: Adds new records without deleting. Historical snapshots of all syncs.
**Append + Deduped**: Appends to raw table, maintains deduped view with latest records using `ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC)`.

## Sync Mode Combinations

### 1. Full Refresh Overwrite
Latest snapshot only. Simple, no cursors needed. Handles schema changes. Loses historical data.

### 2. Full Refresh Append
Historical snapshots. Keep audit trail. Storage grows quickly.

### 3. Incremental Append
All events/records. Efficient (only new data). No deduplication -- duplicates if records update.

### 4. Incremental Append + Deduped
Latest + history. Efficient + accurate. SCD Type 2 history in raw table. Requires primary key and cursor field.

```yaml
streams:
  - stream_name: orders
    sync_mode: incremental_append_deduped
    cursor_field: [updated_at]
    primary_key: [order_id]
```

## Cursor Field Selection

| Field Type | Suitability | Notes |
|------------|-------------|-------|
| `updated_at` | Excellent | Best for mutable records |
| `created_at` | Good | For append-only data |
| Auto-increment ID | Good | Monotonic, reliable |
| UUID | Poor | Non-sequential |

## Common Mistakes

| Don't | Do |
|-------|-----|
| Full refresh for 100M-row table | Incremental with cursor field |
| `created_at` cursor for mutable data | `updated_at` cursor |
| Skip primary key on deduped mode | Always define primary key |

## Related

- [connectors](../concepts/connectors.md)
- [connections](../concepts/connections.md)
- [normalization](../concepts/normalization.md)
- [incremental-dedup-pattern](../patterns/incremental-dedup-pattern.md)
