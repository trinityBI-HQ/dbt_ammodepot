# Catalog and Schema

> **Purpose**: Schema discovery, stream configuration, and field selection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The catalog in Airbyte represents the discovered schema of a source, including all available streams (tables/endpoints), their fields, data types, and supported sync modes. When you configure a connection, Airbyte performs schema discovery to generate a catalog, which you then customize to select which streams and fields to sync. The catalog is the contract between source and destination.

## The Pattern

```json
{
  "catalog": {
    "streams": [
      {
        "stream": {
          "name": "users",
          "jsonSchema": {
            "type": "object",
            "properties": {
              "id": {"type": "integer"},
              "email": {"type": "string"},
              "created_at": {"type": "string", "format": "date-time"},
              "metadata": {"type": "object"}
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
          "selected": true,
          "fieldSelection": {
            "selected": true,
            "fieldSelectionEnabled": false
          }
        }
      }
    ]
  }
}
```

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

## Schema Discovery

When you configure a source, Airbyte performs **discovery**:

```python
# API call (automatic during connection setup)
POST /v1/sources/{sourceId}/discover
{
  "sourceId": "source-uuid"
}

# Returns catalog with all streams
```

Discovery retrieves:
- Available streams (tables, API endpoints)
- Field names and data types
- Primary keys (if defined)
- Recommended cursor fields for incremental sync
- Supported sync modes per stream

## JSON Schema Format

Airbyte uses JSON Schema Draft-07 to define field types:

```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "integer"
    },
    "name": {
      "type": "string"
    },
    "price": {
      "type": "number"
    },
    "is_active": {
      "type": "boolean"
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"}
    },
    "metadata": {
      "type": "object",
      "properties": {
        "created_by": {"type": "string"}
      }
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "airbyte_type": "timestamp_with_timezone"
    }
  }
}
```

### Airbyte-Specific Types

| `airbyte_type` | Description | Example |
|----------------|-------------|---------|
| `timestamp_with_timezone` | Timestamp with TZ | `"2024-02-05T08:00:00Z"` |
| `timestamp_without_timezone` | Timestamp without TZ | `"2024-02-05 08:00:00"` |
| `date` | Date only | `"2024-02-05"` |
| `time_with_timezone` | Time with TZ | `"08:00:00+00:00"` |
| `time_without_timezone` | Time without TZ | `"08:00:00"` |
| `big_integer` | Large integer (> 64-bit) | `"999999999999999999"` |
| `big_number` | Arbitrary precision decimal | `"123.456789012345"` |

## Stream Configuration

Each stream has a configuration object:

```json
{
  "config": {
    "syncMode": "incremental",
    "destinationSyncMode": "append_deduped",
    "cursorField": ["updated_at"],
    "primaryKey": [["id"]],
    "selected": true,
    "aliasName": "customer_users",
    "fieldSelection": {
      "selected": false,
      "fieldSelectionEnabled": true
    }
  }
}
```

### Configuration Fields

**`syncMode`**: How to read from source
- `full_refresh` – Read all records
- `incremental` – Read new/updated records only

**`destinationSyncMode`**: How to write to destination
- `overwrite` – Replace table
- `append` – Add to table
- `append_deduped` – Add and maintain deduped view

**`cursorField`**: Field for incremental sync (array of strings for nested fields)
```json
"cursorField": ["user", "updated_at"]  // Nested field
```

**`primaryKey`**: Composite primary key support
```json
"primaryKey": [["user_id"], ["tenant_id"]]  // Composite key
```

**`selected`**: Whether to sync this stream
```json
"selected": true  // Sync enabled
```

**`aliasName`**: Rename stream in destination
```json
"aliasName": "prod_users"  // users → prod_users
```

## Field Selection

Choose specific fields to sync (not all connectors support this):

```json
{
  "fieldSelection": {
    "selected": true,
    "fieldSelectionEnabled": true
  },
  "selectedFields": [
    {"fieldPath": ["id"]},
    {"fieldPath": ["email"]},
    {"fieldPath": ["metadata", "created_by"]}
  ]
}
```

**Benefits:**
- Reduce data transfer costs
- Exclude sensitive fields (PII)
- Minimize storage usage

## Schema Changes

When source schema changes (new columns, renamed fields):

1. **Auto-detection**: Airbyte detects schema changes during sync
2. **Notification**: UI shows "Schema changes detected"
3. **Review**: Review new/removed/modified fields
4. **Action**: Accept changes or trigger full refresh

```json
{
  "schemaChange": "breaking",  // or "non_breaking"
  "changes": [
    {
      "type": "field_added",
      "streamName": "users",
      "fieldName": "phone_number"
    },
    {
      "type": "field_removed",
      "streamName": "users",
      "fieldName": "fax"
    }
  ]
}
```

## Common Mistakes

### Wrong

```json
// Anti-pattern: Wrong cursor field structure
{
  "cursorField": "updated_at"  // String instead of array
}
```

### Correct

```json
// Correct: Array format
{
  "cursorField": ["updated_at"]  // Array of strings
}

// For nested fields
{
  "cursorField": ["metadata", "updated_at"]
}
```

## Catalog Manipulation

### Programmatically Select Streams

```python
# Get current catalog
response = requests.get(
    f"{API_URL}/connections/{connection_id}",
    headers=headers
)

catalog = response.json()["syncCatalog"]

# Select only specific streams
for stream in catalog["streams"]:
    if stream["stream"]["name"] in ["users", "orders"]:
        stream["config"]["selected"] = True
    else:
        stream["config"]["selected"] = False

# Update connection
requests.put(
    f"{API_URL}/connections/{connection_id}",
    headers=headers,
    json={"syncCatalog": catalog}
)
```

## Related

- [connectors](../concepts/connectors.md)
- [sync-modes](../concepts/sync-modes.md)
- [connections](../concepts/connections.md)
