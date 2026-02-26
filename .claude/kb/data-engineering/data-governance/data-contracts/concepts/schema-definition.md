# Schema Definition

> **Purpose**: Schema formats, field specifications, constraints, and evolution rules
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The schema is the structural backbone of a data contract. It defines what fields exist, their types, constraints, and relationships. A well-defined schema prevents silent breakage and enables automated validation at pipeline boundaries.

## Schema Formats

### ODCS Schema (YAML)

```yaml
schema:
  - name: customer_id
    logicalType: string
    physicalType: VARCHAR(36)
    required: true
    unique: true
    primaryKey: true
    description: "UUID v4 customer identifier"
  - name: email
    logicalType: string
    physicalType: VARCHAR(255)
    required: true
    pattern: "^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$"
    classification: PII
  - name: created_at
    logicalType: timestamp
    required: true
    description: "Account creation timestamp (UTC)"
```

### JSON Schema

```json
{
  "type": "object",
  "required": ["customer_id", "email"],
  "properties": {
    "customer_id": {
      "type": "string",
      "format": "uuid"
    },
    "email": {
      "type": "string",
      "format": "email"
    }
  }
}
```

### Protobuf

```protobuf
message Customer {
  string customer_id = 1;
  string email = 2;
  google.protobuf.Timestamp created_at = 3;
}
```

## Field Constraints

| Constraint | Purpose | Example |
|-----------|---------|---------|
| `required` | Field must be present and non-null | `required: true` |
| `unique` | No duplicate values allowed | `unique: true` |
| `primaryKey` | Identifies the record | `primaryKey: true` |
| `pattern` | Regex validation | `pattern: "^[A-Z]{3}$"` |
| `enum` | Allowed values | `enum: [active, inactive]` |
| `minimum/maximum` | Numeric range | `minimum: 0, maximum: 100` |
| `minLength/maxLength` | String length | `minLength: 1` |
| `format` | Standard format | `format: email, uuid, date` |

## Logical vs Physical Types

Contracts separate **logical types** (business meaning) from **physical types** (storage):

| Logical Type | Snowflake | BigQuery | Spark |
|-------------|-----------|----------|-------|
| `string` | VARCHAR | STRING | StringType |
| `integer` | INTEGER | INT64 | IntegerType |
| `decimal` | NUMBER(38,2) | NUMERIC | DecimalType |
| `timestamp` | TIMESTAMP_NTZ | TIMESTAMP | TimestampType |
| `boolean` | BOOLEAN | BOOL | BooleanType |
| `date` | DATE | DATE | DateType |

## Schema Evolution Rules

### Safe Changes (Non-Breaking)
- Adding a new optional field
- Widening a field type (INT → BIGINT)
- Adding a new enum value
- Relaxing a constraint (required → optional)

### Breaking Changes (Require Major Version Bump)
- Removing a field
- Renaming a field
- Changing a field type incompatibly
- Adding a `required` constraint to existing field
- Narrowing enum values

## Common Mistakes

### Wrong

```yaml
# No types, no constraints — just field names
schema:
  - name: id
  - name: amount
  - name: date
```

### Correct

```yaml
schema:
  - name: order_id
    logicalType: string
    required: true
    unique: true
    description: "Unique order identifier"
  - name: amount
    logicalType: decimal
    required: true
    constraints:
      minimum: 0
  - name: order_date
    logicalType: date
    required: true
```

## Related

- [Fundamentals](fundamentals.md)
- [Versioning](versioning.md)
- [ODCS Specification](../patterns/odcs-specification.md)
