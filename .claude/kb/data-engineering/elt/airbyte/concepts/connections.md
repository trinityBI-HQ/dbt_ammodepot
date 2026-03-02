# Connections

> **Purpose**: Configured syncs between a source and destination with scheduling and stream selection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A connection in Airbyte links a source to a destination and defines how data flows between them. It specifies which streams to sync, the sync mode for each stream, the schedule, and transformation options. **2.0 Updates**: Connections support Files + Records in one connection (v1.7+) and AI-configured connections (Dec 2025) that auto-select connectors and map fields from natural language.

## Quick Reference

| Setting | Options | Default | Purpose |
|---------|---------|---------|---------|
| `schedule` | manual, cron, interval | manual | When to sync |
| `namespaceDefinition` | source, destination, custom | source | Target schema/dataset |
| `prefix` | string | "" | Prefix for destination tables |
| `syncMode` | full_refresh, incremental | varies | How to read |
| `destinationSyncMode` | overwrite, append, append_deduped | varies | How to write |

## The Pattern

```python
{
  "name": "Postgres -> Snowflake",
  "sourceId": "uuid-of-postgres-source",
  "destinationId": "uuid-of-snowflake-dest",
  "schedule": {"scheduleType": "cron", "cronExpression": "0 */6 * * *"},
  "namespaceDefinition": "destination",
  "namespaceFormat": "analytics",
  "prefix": "raw_",
  "syncCatalog": {
    "streams": [{
      "stream": {"name": "users"},
      "config": {
        "syncMode": "incremental",
        "destinationSyncMode": "append_deduped",
        "cursorField": ["updated_at"],
        "primaryKey": [["id"]],
        "selected": true
      }
    }]
  }
}
```

## Schedule Types

**Manual**: Triggered via UI, API, or orchestrator.
**Cron**: Standard cron expressions (UTC) -- `"0 2 * * *"` (daily 2 AM UTC).
**Interval**: Simple recurring -- `{scheduleType: "basic", timeUnit: "hours", units: 12}`.

## Namespace Mapping

| Definition | Behavior | Use Case |
|------------|----------|----------|
| `source` | Preserve source schema name | Keep source structure |
| `destination` | Use destination default schema | Centralized schema |
| `custom` | Template: `${SOURCE_NAMESPACE}` | Template-based naming |

Table prefix: `prefix: "airbyte_"` results in `users` -> `airbyte_users`.

## Stream Selection

Each stream individually configured with `selected`, `syncMode`, `destinationSyncMode`, `cursorField`, `primaryKey`, and optional `aliasName` for renaming.

## Sync Execution

1. **Discovery**: Refresh source schema (optional)
2. **Read**: Extract data using sync mode
3. **Load**: Write to destination
4. **Normalization**: Transform raw JSON to typed tables (if enabled)
5. **Logging**: Store sync logs and statistics

## Connection States

| State | Meaning | Action |
|-------|---------|--------|
| `active` | Scheduled syncs running | Normal operation |
| `inactive` | Paused | No automatic syncs |
| `deprecated` | Connector outdated | Upgrade required |
| `failed` | Last sync failed | Check logs |

## Connection Reset

`POST /v1/connections/{connectionId}/reset` clears destination data and sync state. Use for schema changes, corrupted data, or switching sync modes. **Warning**: Deletes destination data.

## Common Mistakes

| Don't | Do |
|-------|-----|
| 50+ streams in one hourly connection | Separate by domain and criticality |
| Same schedule for all streams | Frequent for critical, daily for analytics |
| Manual changes in UI | Manage via Terraform/API |

## Related

- [connectors](../concepts/connectors.md)
- [sync-modes](../concepts/sync-modes.md)
- [catalog-schema](../concepts/catalog-schema.md)
- [terraform-orchestration](../patterns/terraform-orchestration.md)
