# Normalization

> **Purpose**: Transform raw JSON data into typed, relational tables using dbt
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Normalization in Airbyte transforms raw JSON blobs from sources into typed, relational tables suitable for analytics. Previously called "Basic Normalization," this feature uses dbt under the hood. As of 2024, Airbyte has migrated to "Typing and Deduping" for Destinations V2, which is more performant and flexible.

## Quick Reference

| Feature | Legacy (Basic Normalization) | Current (Typing & Deduping) |
|---------|------------------------------|----------------------------|
| Engine | dbt base-normalization | Native SQL (destination-specific) |
| Performance | Slower | Faster |
| Nested objects | Flattened to separate tables | Flattened |
| Arrays | Expanded to separate tables | Expanded |
| Deduplication | Optional | Built-in for append_deduped |
| Status | Deprecated | Active |

## How It Works

**Step 1 - Raw Load**: Airbyte loads raw JSON into `_airbyte_raw_<stream_name>` with columns `_airbyte_ab_id`, `_airbyte_data` (JSON), and `_airbyte_emitted_at`.

**Step 2 - Type Casting**: JSON types map to SQL types (string->VARCHAR, number->NUMBER/BIGINT, boolean->BOOLEAN, object->VARIANT/JSONB, array->ARRAY/JSONB).

**Step 3 - Flatten Nested Objects**: Nested keys become columns (e.g., `address.city` -> `address_city`).

**Step 4 - Expand Arrays**: Arrays become separate tables with foreign keys.

**Step 5 - Deduplication**: For `append_deduped` mode, keeps only the latest version per primary key using `ROW_NUMBER() OVER (PARTITION BY id ORDER BY _airbyte_emitted_at DESC)`.

## Typing and Deduping (Destinations V2)

Improvements over Basic Normalization: native SQL (no dbt overhead), incremental updates (only process new data), better error handling, reduced storage.

```sql
-- Generated MERGE (example for Snowflake)
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

## Configuration

```yaml
# Destinations V2 (current)
normalization: typing_and_deduping

# Legacy
normalization: basic
```

**Disable normalization** when using dbt downstream, loading to a data lake (S3, GCS), or minimizing sync time/compute costs.

## Custom dbt Transformations

For advanced use cases, run custom dbt models on top of Airbyte raw tables:

```sql
-- models/staging/stg_users.sql
SELECT
  (_airbyte_data:id)::INT AS user_id,
  (_airbyte_data:name)::VARCHAR AS user_name,
  (_airbyte_data:email)::VARCHAR AS email,
  _airbyte_emitted_at AS extracted_at
FROM {{ source('airbyte_raw', '_airbyte_raw_users') }}
```

## Common Mistakes

| Don't | Do |
|-------|-----|
| Enable normalization for data lakes (S3) | Set `normalization: none` for lakes |
| Stay on legacy Basic Normalization | Upgrade to Typing and Deduping (Destinations V2) |
| Skip testing after migration | Full refresh after migrating to V2 |

## Migration from Basic Normalization

1. Upgrade destination connector to V2
2. Switch to Typing and Deduping in connection settings
3. Test in dev environment first
4. Perform full refresh after migration

## Related

- [sync-modes](../concepts/sync-modes.md)
- [connections](../concepts/connections.md)
- [incremental-dedup-pattern](../patterns/incremental-dedup-pattern.md)
