# Sources and Seeds

> **Purpose**: Define raw data sources and load static seed data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Sources declare raw data tables loaded by EL tools, enabling lineage tracking and freshness monitoring. Seeds are CSV files in your project that dbt loads into the warehouse, ideal for small static reference data like country codes or employee IDs.

## Source Definition

```yaml
# models/staging/_sources.yml
version: 2

sources:
  - name: raw
    database: raw_db
    schema: public
    tables:
      - name: orders
        description: "Raw orders from Shopify"
        loaded_at_field: _etl_loaded_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
        columns:
          - name: id
            tests:
              - unique
              - not_null
      - name: customers
        description: "Raw customer data"
```

## Using Sources in Models

```sql
-- models/staging/stg_orders.sql
select
    id as order_id,
    user_id,
    status
from {{ source('raw', 'orders') }}
```

## Seed Example

```csv
# seeds/country_codes.csv
code,name,region
US,United States,North America
CA,Canada,North America
MX,Mexico,North America
```

```yaml
# seeds/_seeds.yml
version: 2

seeds:
  - name: country_codes
    description: "ISO country codes"
    config:
      column_types:
        code: varchar(2)
```

## Commands

| Command | Purpose |
|---------|---------|
| `dbt source freshness` | Check data age |
| `dbt seed` | Load CSV files |
| `dbt seed --full-refresh` | Reload all seeds |

## Common Mistakes

### Wrong

```sql
-- Direct table reference, no lineage
select * from raw_db.public.orders
```

### Correct

```sql
-- Source function enables lineage
select * from {{ source('raw', 'orders') }}
```

## Related

- [testing](testing.md)
- [models-materializations](models-materializations.md)
