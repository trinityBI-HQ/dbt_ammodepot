# Incremental Dedup Pattern

> **Purpose**: Efficiently sync large, mutable datasets with incremental append + deduplication
> **MCP Validated**: 2026-02-19

## When to Use

- Large tables (>100K rows) with frequent updates
- Mutable records (customers, orders, inventory)
- Need complete change history (SCD Type 2)
- Want to minimize data transfer and API calls
- Source has reliable `updated_at` or cursor field

## Implementation

```yaml
connection:
  name: "Postgres -> Snowflake (Incremental Dedup)"
streams:
  - name: customers
    sync_mode: incremental
    destination_sync_mode: append_deduped
    cursor_field: [updated_at]
    primary_key: [[customer_id]]
  - name: orders
    sync_mode: incremental
    destination_sync_mode: append_deduped
    cursor_field: [updated_at]
    primary_key: [[order_id]]
```

## How It Works

### Step 1: Initial Sync (Full Refresh)

First sync reads all records into `_airbyte_raw_<stream>` with `_airbyte_ab_id`, `_airbyte_data` (JSON), and `_airbyte_emitted_at`.

### Step 2: Incremental Syncs

Subsequent syncs fetch only changed records: `SELECT * FROM customers WHERE updated_at > '<last_sync_timestamp>'`. New records are appended to the raw table alongside existing ones.

### Step 3: Deduplication

Typing and Deduping creates a view with latest records per primary key:

```sql
CREATE OR REPLACE VIEW customers AS
SELECT customer_id, name, updated_at, _airbyte_extracted_at, _airbyte_meta
FROM (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY updated_at DESC, _airbyte_emitted_at DESC
  ) AS row_num
  FROM _airbyte_raw_customers
)
WHERE row_num = 1;
```

## Configuration

| Setting | Requirement | Description |
|---------|-------------|-------------|
| `cursor_field` | Required | Field tracking updates (e.g., `updated_at`) |
| `primary_key` | Required | Unique identifier for deduplication |
| `sync_mode` | `incremental` | Read only new/changed records |
| `destination_sync_mode` | `append_deduped` | Append + maintain deduped view |

## Cursor Field Selection

### Good Cursors

```sql
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- For append-only
version INTEGER DEFAULT 0
```

### Bad Cursors

```sql
priority INTEGER  -- Non-monotonic (can decrease)
last_login TIMESTAMP  -- Only updates on login, misses other changes
id UUID  -- Random, not ordered
```

## SCD Type 2 History

Raw table retains full history; deduped view shows current state:

```sql
-- Full history
SELECT customer_id, name, updated_at FROM _airbyte_raw_customers
WHERE customer_id = 1 ORDER BY updated_at;
-- Returns: Alice (Jan 1) -> Alice Smith (Jan 15) -> Alice Updated (Feb 5)

-- Current state (deduped view)
SELECT customer_id, name FROM customers WHERE customer_id = 1;
-- Returns: Alice Updated
```

## Performance Optimization

```sql
-- Index cursor field on source
CREATE INDEX idx_customers_updated_at ON customers(updated_at);

-- Cluster raw table in Snowflake
ALTER TABLE _airbyte_raw_customers
CLUSTER BY (_airbyte_data:customer_id::INTEGER, _airbyte_emitted_at);
```

## Error Handling

**Missing cursor field**: Add `updated_at` column with trigger:
```sql
ALTER TABLE customers ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
CREATE TRIGGER update_timestamp BEFORE UPDATE ON customers
FOR EACH ROW SET NEW.updated_at = CURRENT_TIMESTAMP;
```

**Null cursors**: Records with NULL cursor are synced once and not again until cursor becomes non-null.

## Example Usage

```python
# Via API
config = {
  "syncCatalog": {"streams": [{
    "stream": {"name": "customers"},
    "config": {
      "syncMode": "incremental", "destinationSyncMode": "append_deduped",
      "cursorField": ["updated_at"], "primaryKey": [["customer_id"]], "selected": True
    }
  }]}
}
```

## Monitoring

```sql
-- Track sync volume over time
SELECT DATE(_airbyte_emitted_at) AS sync_date, COUNT(*) AS records_synced,
  COUNT(DISTINCT _airbyte_data:customer_id) AS unique_customers
FROM _airbyte_raw_customers GROUP BY sync_date ORDER BY sync_date;
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| `created_at` for mutable data | Use `updated_at` |
| Missing primary key | Always define primary key |
| Nullable cursor field | Ensure cursor is NOT NULL |
| No index on cursor | Index for query performance |
| Full refresh for large tables | Use incremental |

## See Also

- [sync-modes](../concepts/sync-modes.md)
- [normalization](../concepts/normalization.md)
- [connections](../concepts/connections.md)
