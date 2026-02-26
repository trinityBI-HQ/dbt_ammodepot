# Incremental Dedup Pattern

> **Purpose**: Efficiently sync large, mutable datasets with incremental append + deduplication
> **MCP Validated**: 2026-02-19

## When to Use

- Large tables (> 100K rows) with frequent updates
- Mutable records that change over time (customers, orders, inventory)
- Need complete change history (SCD Type 2)
- Want to minimize data transfer and API calls
- Source has reliable `updated_at` or cursor field

## Implementation

```yaml
# Connection configuration
connection:
  name: "Postgres → Snowflake (Incremental Dedup)"
  sync_mode: incremental_append_deduped

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

First sync reads all records:

```sql
-- Source query (initial)
SELECT * FROM customers;

-- Destination: _airbyte_raw_customers
| _airbyte_ab_id | _airbyte_data                          | _airbyte_emitted_at |
|----------------|---------------------------------------|---------------------|
| uuid-1         | {"customer_id": 1, "name": "Alice"}   | 2024-02-05 08:00    |
| uuid-2         | {"customer_id": 2, "name": "Bob"}     | 2024-02-05 08:00    |
```

### Step 2: Incremental Syncs

Subsequent syncs only fetch changed records:

```sql
-- Source query (incremental)
SELECT * FROM customers
WHERE updated_at > '2024-02-05 08:00:00'  -- Last sync timestamp

-- New records appended
| _airbyte_ab_id | _airbyte_data                                  | _airbyte_emitted_at |
|----------------|-----------------------------------------------|---------------------|
| uuid-1         | {"customer_id": 1, "name": "Alice"}           | 2024-02-05 08:00    |
| uuid-2         | {"customer_id": 2, "name": "Bob"}             | 2024-02-05 08:00    |
| uuid-3         | {"customer_id": 1, "name": "Alice Updated"}   | 2024-02-05 14:00    |
| uuid-4         | {"customer_id": 3, "name": "Charlie"}         | 2024-02-05 14:00    |
```

### Step 3: Deduplication

Typing and Deduping creates a view with latest records:

```sql
-- Deduped view (automated by Airbyte)
CREATE OR REPLACE VIEW customers AS
SELECT
  customer_id,
  name,
  updated_at,
  _airbyte_extracted_at,
  _airbyte_meta
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY updated_at DESC, _airbyte_emitted_at DESC
    ) AS row_num
  FROM _airbyte_raw_customers
)
WHERE row_num = 1;

-- Result
| customer_id | name           | updated_at          |
|-------------|----------------|---------------------|
| 1           | Alice Updated  | 2024-02-05 14:00    |
| 2           | Bob            | 2024-02-05 08:00    |
| 3           | Charlie        | 2024-02-05 14:00    |
```

## Configuration

| Setting | Requirement | Description |
|---------|-------------|-------------|
| `cursor_field` | Required | Field tracking record updates (e.g., `updated_at`) |
| `primary_key` | Required | Unique identifier for deduplication |
| `sync_mode` | `incremental` | Read only new/changed records |
| `destination_sync_mode` | `append_deduped` | Append + maintain deduped view |

## Cursor Field Selection

### Good Cursor Fields

```sql
-- Timestamp updated on every change
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- Auto-incrementing ID (for append-only)
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

-- Version number
version INTEGER DEFAULT 0
```

### Bad Cursor Fields

```sql
-- Non-monotonic (can decrease)
priority INTEGER  -- Can go from 5 → 3

-- Not updated reliably
last_login TIMESTAMP  -- Only updates on login

-- Non-sequential UUID
id UUID  -- Random, not ordered
```

## SCD Type 2 History

With incremental append + dedup, you maintain complete change history:

```sql
-- Raw table: Full history
SELECT customer_id, name, updated_at, _airbyte_emitted_at
FROM _airbyte_raw_customers
WHERE customer_id = 1
ORDER BY updated_at;

| customer_id | name           | updated_at          | _airbyte_emitted_at |
|-------------|----------------|---------------------|---------------------|
| 1           | Alice          | 2024-01-01 00:00    | 2024-01-01 08:00    |
| 1           | Alice Smith    | 2024-01-15 12:00    | 2024-01-15 14:00    |
| 1           | Alice Updated  | 2024-02-05 14:00    | 2024-02-05 15:00    |

-- Deduped view: Current state
SELECT customer_id, name, updated_at
FROM customers
WHERE customer_id = 1;

| customer_id | name           | updated_at          |
|-------------|----------------|---------------------|
| 1           | Alice Updated  | 2024-02-05 14:00    |
```

## Performance Optimization

### Index Cursor Field

```sql
-- On source database
CREATE INDEX idx_customers_updated_at ON customers(updated_at);

-- Query performance
EXPLAIN SELECT * FROM customers WHERE updated_at > '2024-02-05';
-- Should use index scan, not full table scan
```

### Partition Raw Table

```sql
-- Snowflake example
CREATE TABLE _airbyte_raw_customers (
  _airbyte_ab_id STRING,
  _airbyte_data VARIANT,
  _airbyte_emitted_at TIMESTAMP_NTZ
)
CLUSTER BY (_airbyte_emitted_at);

-- Improve dedup query performance
ALTER TABLE _airbyte_raw_customers
CLUSTER BY (
  _airbyte_data:customer_id::INTEGER,
  _airbyte_emitted_at
);
```

## Error Handling

### Missing Cursor Field

```yaml
# If source doesn't have updated_at, add it
ALTER TABLE customers ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

# Create trigger to update on changes (MySQL)
CREATE TRIGGER update_customers_timestamp
BEFORE UPDATE ON customers
FOR EACH ROW
SET NEW.updated_at = CURRENT_TIMESTAMP;
```

### Cursor Field Nulls

```yaml
# Handle nulls in cursor field
cursor_field: [updated_at]

# Airbyte behavior:
# - Records with NULL cursor are synced once
# - Not synced again unless cursor becomes non-null
```

## Example Usage

```python
# Via API
connection_config = {
  "syncCatalog": {
    "streams": [
      {
        "stream": {"name": "customers"},
        "config": {
          "syncMode": "incremental",
          "destinationSyncMode": "append_deduped",
          "cursorField": ["updated_at"],
          "primaryKey": [["customer_id"]],
          "selected": True
        }
      }
    ]
  }
}

# Via Terraform
resource "airbyte_connection" "postgres_to_snowflake" {
  configurations = {
    streams = [
      {
        name = "customers"
        sync_mode = "incremental_append_deduped"
        cursor_field = ["updated_at"]
        primary_key = [["customer_id"]]
      }
    ]
  }
}
```

## Monitoring

Track incremental sync efficiency:

```sql
-- Check sync volume over time
SELECT
  DATE(_airbyte_emitted_at) AS sync_date,
  COUNT(*) AS records_synced,
  COUNT(DISTINCT _airbyte_data:customer_id) AS unique_customers
FROM _airbyte_raw_customers
GROUP BY sync_date
ORDER BY sync_date;

-- Identify frequently updated records
SELECT
  _airbyte_data:customer_id AS customer_id,
  COUNT(*) AS update_count
FROM _airbyte_raw_customers
GROUP BY customer_id
HAVING COUNT(*) > 10
ORDER BY update_count DESC;
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Use `created_at` for mutable data | Use `updated_at` |
| Missing primary key | Always define primary key |
| Nullable cursor field | Ensure cursor is NOT NULL |
| No index on cursor | Index for performance |
| Full refresh for large tables | Use incremental |

## See Also

- [sync-modes](../concepts/sync-modes.md)
- [normalization](../concepts/normalization.md)
- [connections](../concepts/connections.md)
