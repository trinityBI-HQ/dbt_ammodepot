# Connections

> **Purpose**: Configured syncs between a source and destination with scheduling and stream selection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A connection in Airbyte links a source to a destination and defines how data flows between them. It specifies which streams (tables/endpoints) to sync, the sync mode for each stream, the sync schedule, and transformation options. Connections are the core execution unit in Airbyte, representing a configured data pipeline.

**2.0 Updates**: Connections now support **Files + Records in one connection** (v1.7+) and **AI-configured connections** (Dec 2025) that auto-select connectors, map fields, and set sync modes from natural language descriptions.

## The Pattern

```python
# Connection configuration (API/Terraform)
{
  "name": "Postgres → Snowflake",
  "sourceId": "uuid-of-postgres-source",
  "destinationId": "uuid-of-snowflake-dest",
  "schedule": {
    "scheduleType": "cron",
    "cronExpression": "0 */6 * * *"  # Every 6 hours
  },
  "namespaceDefinition": "destination",
  "namespaceFormat": "analytics",
  "prefix": "raw_",
  "syncCatalog": {
    "streams": [
      {
        "stream": {"name": "users"},
        "config": {
          "syncMode": "incremental",
          "destinationSyncMode": "append_deduped",
          "cursorField": ["updated_at"],
          "primaryKey": [["id"]],
          "selected": true
        }
      }
    ]
  }
}
```

## Quick Reference

| Setting | Options | Default | Purpose |
|---------|---------|---------|---------|
| `schedule` | manual, cron, interval | manual | When to sync |
| `namespaceDefinition` | source, destination, custom | source | Target schema/dataset |
| `prefix` | string | "" | Prefix for destination tables |
| `syncMode` | full_refresh, incremental | varies | How to read |
| `destinationSyncMode` | overwrite, append, append_deduped | varies | How to write |

## Connection Configuration

### Schedule Types

**Manual**: Triggered via UI, API, or orchestrator

```yaml
schedule:
  scheduleType: manual
```

**Cron**: Standard cron expressions (UTC timezone)

```yaml
schedule:
  scheduleType: cron
  cronExpression: "0 2 * * *"  # Daily at 2 AM UTC
```

**Interval**: Simple recurring intervals

```yaml
schedule:
  scheduleType: basic
  timeUnit: hours
  units: 12  # Every 12 hours
```

### Namespace Mapping

Controls destination schema/dataset naming:

| Definition | Example Source | Example Destination | Use Case |
|------------|----------------|---------------------|----------|
| `source` | `public` | `public` | Preserve source structure |
| `destination` | (ignored) | `analytics` | Centralized schema |
| `custom` | (custom format) | `${SOURCE}_${NAMESPACE}` | Template-based |

```python
# Custom namespace format example
namespaceDefinition: "custom"
namespaceFormat: "raw_${SOURCE_NAMESPACE}"

# Result: public.users → raw_public.users
```

### Table Prefix

Add prefix to all destination tables:

```yaml
prefix: "airbyte_"

# Result: users → airbyte_users
```

## Stream Selection

Each stream in the catalog can be individually configured:

```python
{
  "stream": {"name": "orders"},
  "config": {
    "selected": true,  # Enable this stream
    "syncMode": "incremental",
    "destinationSyncMode": "append_deduped",
    "cursorField": ["updated_at"],
    "primaryKey": [["order_id"]],
    "aliasName": "sales_orders"  # Optional rename
  }
}
```

**Stream states:**
- `selected: true` – Sync this stream
- `selected: false` – Skip this stream
- Field selection – Choose specific columns (not all connectors)

## Sync Execution

When a sync runs:

1. **Discovery**: Refresh source schema (optional)
2. **Read**: Extract data from source using sync mode
3. **Load**: Write data to destination
4. **Normalization**: Transform raw JSON to typed tables (if enabled)
5. **Logging**: Store sync logs and statistics

```bash
# Sync output
Read 10,543 records from 3 streams
Wrote 10,543 records to destination
Normalization complete: 3 tables updated
Sync completed in 2m 34s
```

## Connection States

| State | Meaning | Action |
|-------|---------|--------|
| `active` | Scheduled syncs running | Normal operation |
| `inactive` | Paused | No automatic syncs |
| `deprecated` | Connector version outdated | Upgrade required |
| `failed` | Last sync failed | Check logs |

## Sync History

Airbyte maintains sync history for each connection:

```json
{
  "jobId": 12345,
  "status": "succeeded",
  "recordsSynced": 10543,
  "bytesSynced": 5242880,
  "startTime": "2024-02-05T08:00:00Z",
  "endTime": "2024-02-05T08:02:34Z",
  "streams": [
    {"streamName": "users", "recordsSynced": 234},
    {"streamName": "orders", "recordsSynced": 10309}
  ]
}
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: All streams in one connection
{
  "syncCatalog": {
    "streams": [
      {"stream": {"name": "users"}, "config": {"selected": true}},
      {"stream": {"name": "orders"}, "config": {"selected": true}},
      # ... 50 more streams
    ]
  },
  "schedule": {
    "cronExpression": "0 * * * *"  # Every hour
  }
}
# Problem: One stream failure blocks all others
```

### Correct

```python
# Correct: Separate connections by domain and criticality
# Connection 1: Critical customer data (frequent)
{
  "name": "Postgres → Snowflake (Customer Data)",
  "syncCatalog": {
    "streams": [
      {"stream": {"name": "users"}},
      {"stream": {"name": "customers"}}
    ]
  },
  "schedule": {"cronExpression": "0 */2 * * *"}  # Every 2 hours
}

# Connection 2: Analytics data (less frequent)
{
  "name": "Postgres → Snowflake (Analytics)",
  "syncCatalog": {
    "streams": [
      {"stream": {"name": "orders"}},
      {"stream": {"name": "transactions"}}
    ]
  },
  "schedule": {"cronExpression": "0 6 * * *"}  # Once daily
}
```

## Connection Reset

A **reset** clears destination data and sync state:

```bash
# Via API
POST /v1/connections/{connectionId}/reset
```

**Use cases:**
- Schema changes requiring clean slate
- Corrupted data in destination
- Switching from full refresh to incremental

**Warning:** Deletes destination data for this connection.

## Related

- [connectors](../concepts/connectors.md)
- [sync-modes](../concepts/sync-modes.md)
- [catalog-schema](../concepts/catalog-schema.md)
- [terraform-orchestration](../patterns/terraform-orchestration.md)
