# Contract Versioning

> **Purpose**: Semantic versioning for data contracts, breaking changes, and migration strategies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Data contracts use semantic versioning (MAJOR.MINOR.PATCH) to communicate changes clearly. Proper versioning prevents silent breakage and gives consumers time to adapt to changes.

## Semantic Versioning for Data

```
MAJOR.MINOR.PATCH

MAJOR — Breaking changes (field removed, type changed incompatibly)
MINOR — Backward-compatible additions (new optional field, new enum value)
PATCH — Non-structural fixes (description update, SLA adjustment)
```

### Version Declaration

```yaml
dataContractSpecification: 0.9.3
id: urn:datacontract:payments:orders
info:
  title: Orders Dataset
  version: 2.1.0
  status: active
```

## Change Classification

### PATCH Changes (x.x.+1)
No consumer impact. Safe to deploy immediately.

- Updated descriptions or documentation
- SLA value adjustments
- Contact information changes
- Added or updated tags/classifications

### MINOR Changes (x.+1.0)
Backward-compatible. Consumers may optionally adopt.

- New optional column added
- New enum value added to existing field
- Relaxed constraint (required → optional)
- Widened type (INT32 → INT64)

### MAJOR Changes (+1.0.0)
Breaking. Consumers **must** update before migration deadline.

- Column removed or renamed
- Data type changed incompatibly (string → integer)
- Required constraint added to existing field
- Enum values removed
- Primary key changed

## Migration Strategies

### Dual-Write Pattern

Run old and new versions simultaneously during migration.

```
Producer → Table v1 (existing consumers)
        → Table v2 (migrating consumers)

Timeline:
  Day 0:  v2 contract published, dual-write begins
  Day 14: Consumer migration deadline
  Day 30: v1 deprecated and removed
```

### View-Based Abstraction

Shield consumers from physical changes using views.

```sql
-- Physical table changes from v1 to v2
-- v1 consumers continue reading from the view
CREATE VIEW orders_v1 AS
SELECT
    order_id,
    customer_name AS name,  -- renamed in v2
    amount
FROM orders_v2;
```

### Blue-Green Contract Deployment

```yaml
# Version routing
contracts:
  - version: "1.x"
    table: orders_v1
    status: deprecated
    sunset: "2026-04-01"
  - version: "2.x"
    table: orders_v2
    status: active
```

## Compatibility Modes

| Mode | Allowed Changes | Use Case |
|------|----------------|----------|
| **BACKWARD** | New optional fields only | Default for most contracts |
| **FORWARD** | Consumers handle unknown fields | Flexible consumers |
| **FULL** | Backward + forward compatible | Strict governance |
| **NONE** | Any change allowed | Development only |

## Deprecation Process

1. **Announce** — Publish deprecation notice with sunset date
2. **Dual-run** — Both versions active, monitoring consumer migration
3. **Warn** — Alert remaining consumers of approaching deadline
4. **Sunset** — Remove deprecated version

```yaml
info:
  version: 1.5.0
  status: deprecated
  deprecation:
    announced: "2026-01-15"
    sunset: "2026-04-15"
    migration_guide: "https://wiki.company.com/orders-v2-migration"
    replacement: "urn:datacontract:payments:orders:v2"
```

## Related

- [Schema Definition](schema-definition.md)
- [ODCS Specification](../patterns/odcs-specification.md)
- [Testing and CI/CD](../patterns/testing-and-cicd.md)
