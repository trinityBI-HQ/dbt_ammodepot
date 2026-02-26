# Normalization

> **Purpose**: Transform raw JSON data into typed, relational tables using dbt
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Normalization in Airbyte transforms raw JSON blobs from sources into typed, relational tables suitable for analytics. Previously called "Basic Normalization," this feature uses dbt under the hood to convert semi-structured data into SQL tables with proper data types. As of 2024, Airbyte has migrated to "Typing and Deduping" for Destinations V2, which is more performant and flexible.

## The Pattern

```sql
-- Raw table created by Airbyte
_airbyte_raw_users
| _airbyte_ab_id | _airbyte_data                              | _airbyte_emitted_at |
|----------------|-------------------------------------------|---------------------|
| uuid-1         | {"id": 1, "name": "Alice", "age": 30}    | 2024-02-05 08:00    |
| uuid-2         | {"id": 2, "name": "Bob", "age": null}    | 2024-02-05 08:00    |

-- Normalized table (after typing/deduping)
users
| id | name  | age  | _airbyte_extracted_at |
|----|-------|------|-----------------------|
| 1  | Alice | 30   | 2024-02-05 08:00      |
| 2  | Bob   | NULL | 2024-02-05 08:00      |
```

## Quick Reference

| Feature | Legacy (Basic Normalization) | Current (Typing & Deduping) |
|---------|------------------------------|----------------------------|
| Engine | dbt base-normalization | Native SQL (destination-specific) |
| Performance | Slower | Faster |
| Nested objects | Flattened to separate tables | Flattened |
| Arrays | Expanded to separate tables | Expanded |
| Type casting | Yes | Yes |
| Deduplication | Optional | Built-in for append_deduped |
| Status | Deprecated | Active |

## How It Works

### Step 1: Extract (Raw Load)

Airbyte loads raw JSON into `_airbyte_raw_<stream_name>`:

```json
{
  "_airbyte_ab_id": "uuid-123",
  "_airbyte_data": {
    "id": 1,
    "name": "Alice",
    "address": {
      "street": "123 Main St",
      "city": "Seattle"
    },
    "orders": [
      {"order_id": 101, "amount": 50.0},
      {"order_id": 102, "amount": 75.0}
    ]
  },
  "_airbyte_emitted_at": "2024-02-05T08:00:00Z"
}
```

### Step 2: Type Casting

Convert JSON types to SQL types:

| JSON Type | SQL Type (Snowflake) | SQL Type (Postgres) |
|-----------|----------------------|---------------------|
| string | VARCHAR | TEXT |
| number (int) | NUMBER | BIGINT |
| number (float) | FLOAT | DOUBLE PRECISION |
| boolean | BOOLEAN | BOOLEAN |
| null | NULL | NULL |
| object | VARIANT/JSON | JSONB |
| array | ARRAY | JSONB |

### Step 3: Flatten Nested Objects

```sql
-- Nested object flattened
users
| id | name  | address_street | address_city |
|----|-------|---------------|--------------|
| 1  | Alice | 123 Main St   | Seattle      |
```

### Step 4: Expand Arrays

Arrays become separate tables with foreign keys:

```sql
users_orders
| _airbyte_users_hashid | order_id | amount |
|-----------------------|----------|--------|
| hash-1                | 101      | 50.0   |
| hash-1                | 102      | 75.0   |
```

### Step 5: Deduplication (Incremental Append + Deduped)

Keep only the latest version of each record:

```sql
-- Deduped view using ROW_NUMBER
CREATE OR REPLACE VIEW users AS
SELECT * FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY id
           ORDER BY _airbyte_emitted_at DESC
         ) AS row_num
  FROM _airbyte_raw_users
) WHERE row_num = 1;
```

## Configuration

Enable normalization in connection settings:

```yaml
# Destinations V2 (current)
normalization: typing_and_deduping

# Legacy
normalization: basic
```

**Disable normalization** when:
- Using dbt downstream for transformations
- Loading to a data lake (S3, GCS) for further processing
- Minimizing sync time and compute costs

## Typing and Deduping (Destinations V2)

Improvements over Basic Normalization:

| Feature | Benefit |
|---------|---------|
| Native SQL | Faster execution (no dbt overhead) |
| Incremental updates | Only process new data |
| Better error handling | Clearer failure messages |
| Reduced storage | No intermediate dbt artifacts |

```sql
-- Generated SQL (example for Snowflake)
MERGE INTO users AS target
USING (
  SELECT
    CAST(_airbyte_data:id AS NUMBER) AS id,
    CAST(_airbyte_data:name AS VARCHAR) AS name,
    _airbyte_emitted_at
  FROM _airbyte_raw_users
  WHERE _airbyte_loaded_at IS NULL
) AS source
ON target.id = source.id
WHEN MATCHED THEN
  UPDATE SET name = source.name, _airbyte_extracted_at = source._airbyte_emitted_at
WHEN NOT MATCHED THEN
  INSERT (id, name, _airbyte_extracted_at)
  VALUES (source.id, source.name, source._airbyte_emitted_at);
```

## Custom dbt Transformations

For advanced use cases, run custom dbt models on top of Airbyte raw tables:

```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +materialized: view
      +schema: staging

# models/staging/stg_users.sql
SELECT
  (_airbyte_data:id)::INT AS user_id,
  (_airbyte_data:name)::VARCHAR AS user_name,
  (_airbyte_data:email)::VARCHAR AS email,
  _airbyte_emitted_at AS extracted_at
FROM {{ source('airbyte_raw', '_airbyte_raw_users') }}
```

## Common Mistakes

### Wrong

```yaml
# Anti-pattern: Enable normalization for data lake
destination: s3
normalization: typing_and_deduping
# Problem: S3 doesn't support SQL transformations
```

### Correct

```yaml
# Correct: Disable normalization for lakes
destination: s3
normalization: none
# Use Spark/Athena for transformations later
```

## Migration from Basic Normalization

If using legacy Basic Normalization:

1. Upgrade destination connector to V2
2. Switch to Typing and Deduping in connection settings
3. Test in dev environment first
4. Perform full refresh after migration

## Related

- [sync-modes](../concepts/sync-modes.md)
- [connections](../concepts/connections.md)
- [incremental-dedup-pattern](../patterns/incremental-dedup-pattern.md)
