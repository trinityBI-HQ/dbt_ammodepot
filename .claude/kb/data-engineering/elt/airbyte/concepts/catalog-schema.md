# Catalog and Schema

> **Purpose**: Schema discovery, stream configuration, and field selection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The catalog in Airbyte represents the discovered schema of a source, including all available streams (tables/endpoints), their fields, data types, and supported sync modes. When you configure a connection, Airbyte performs schema discovery to generate a catalog, which you then customize to select streams and fields. The catalog is the contract between source and destination.

## Quick Reference

| Component | Purpose | Example |
|-----------|---------|---------|
| `stream.name` | Table/endpoint name | `"users"` |
| `jsonSchema` | Field definitions and types | `{"id": {"type": "integer"}}` |
| `supportedSyncModes` | Allowed sync modes | `["full_refresh", "incremental"]` |
| `defaultCursorField` | Recommended cursor | `["updated_at"]` |
| `sourceDefinedPrimaryKey` | Primary key from source | `[["id"]]` |
| `config.selected` | Enable/disable stream | `true` or `false` |
| `config.cursorField` | Field for incremental sync | `["updated_at"]` |

## The Pattern

```json
{
  "catalog": {
    "streams": [{
      "stream": {
        "name": "users",
        "jsonSchema": {
          "type": "object",
          "properties": {
            "id": {"type": "integer"},
            "email": {"type": "string"},
            "created_at": {"type": "string", "format": "date-time"}
          }
        },
        "supportedSyncModes": ["full_refresh", "incremental"],
        "sourceDefinedCursor": true,
        "defaultCursorField": ["created_at"],
        "sourceDefinedPrimaryKey": [["id"]]
      },
      "config": {
        "syncMode": "incremental",
        "destinationSyncMode": "append_deduped",
        "cursorField": ["created_at"],
        "primaryKey": [["id"]],
        "selected": true
      }
    }]
  }
}
```

## Schema Discovery

Airbyte performs discovery via `POST /v1/sources/{sourceId}/discover`, retrieving available streams, field names/types, primary keys, cursor fields, and supported sync modes per stream. Uses JSON Schema Draft-07.

### Airbyte-Specific Types

| `airbyte_type` | Description | Example |
|----------------|-------------|---------|
| `timestamp_with_timezone` | Timestamp with TZ | `"2024-02-05T08:00:00Z"` |
| `timestamp_without_timezone` | Timestamp without TZ | `"2024-02-05 08:00:00"` |
| `date` | Date only | `"2024-02-05"` |
| `big_integer` | Large integer (> 64-bit) | `"999999999999999999"` |
| `big_number` | Arbitrary precision decimal | `"123.456789012345"` |

## Stream Configuration

**`syncMode`**: `full_refresh` (read all) or `incremental` (new/updated only)
**`destinationSyncMode`**: `overwrite` (replace), `append` (add), `append_deduped` (add + dedupe)
**`cursorField`**: Array format -- `["updated_at"]` or nested `["metadata", "updated_at"]`
**`primaryKey`**: Composite support -- `[["user_id"], ["tenant_id"]]`
**`aliasName`**: Rename stream in destination -- `"prod_users"`

## Field Selection

Choose specific fields to sync (not all connectors support this):

```json
{
  "fieldSelection": {"selected": true, "fieldSelectionEnabled": true},
  "selectedFields": [
    {"fieldPath": ["id"]},
    {"fieldPath": ["email"]},
    {"fieldPath": ["metadata", "created_by"]}
  ]
}
```

Benefits: reduce data transfer costs, exclude PII, minimize storage.

## Schema Changes

When source schema changes: Airbyte auto-detects during sync, notifies in UI, allows review of new/removed/modified fields, and lets you accept changes or trigger full refresh. Changes are classified as `breaking` or `non_breaking`.

## Common Mistakes

| Don't | Do |
|-------|-----|
| `"cursorField": "updated_at"` (string) | `"cursorField": ["updated_at"]` (array) |
| Ignore schema change notifications | Review and accept/refresh promptly |
| Select all fields blindly | Use field selection to exclude PII |

## Related

- [connectors](../concepts/connectors.md)
- [sync-modes](../concepts/sync-modes.md)
- [connections](../concepts/connections.md)
