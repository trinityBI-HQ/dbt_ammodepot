# Sources

> **Purpose**: Declare and document raw data tables that dbt models depend on
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Sources define the raw tables in your data warehouse that serve as inputs to your dbt
project. Declaring sources allows you to reference them with `source()`, document them,
test them, and track freshness. Sources are defined in YAML files within your models
directory.

## The Pattern

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw_ecommerce
    description: Raw e-commerce data from production database
    database: raw_db
    schema: ecommerce
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: _loaded_at

    tables:
      - name: orders
        description: Customer orders with status and amounts
        columns:
          - name: order_id
            description: Primary key
            data_tests:
              - unique
              - not_null
          - name: customer_id
            description: FK to customers table
          - name: order_date
            description: Date order was placed

      - name: customers
        description: Customer master data
        columns:
          - name: customer_id
            description: Primary key
            data_tests:
              - unique
              - not_null
```

## Quick Reference

| Property | Purpose | Example |
|----------|---------|---------|
| `name` | Source identifier | `raw_ecommerce` |
| `database` | Target database | `raw_db` |
| `schema` | Target schema | `ecommerce` |
| `freshness` | Staleness check | warn/error thresholds |
| `loaded_at_field` | Timestamp column | `_loaded_at` |

## Using Sources in Models

```sql
-- models/staging/stg_orders.sql
with source as (
    select * from {{ source('raw_ecommerce', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        amount as order_amount,
        _loaded_at as loaded_at
    from source
)

select * from renamed
```

## Common Mistakes

### Wrong

```sql
-- Hardcoding source table breaks lineage tracking
select * from raw_db.ecommerce.orders
```

### Correct

```sql
-- source() enables lineage, freshness, and documentation
select * from {{ source('raw_ecommerce', 'orders') }}
```

## Source Freshness

```bash
# Check freshness of all sources
dbt source freshness

# Check specific source
dbt source freshness --select source:raw_ecommerce
```

## Overriding Source Properties

```yaml
# For different environments (dev vs prod)
sources:
  - name: raw_ecommerce
    database: "{{ env_var('DBT_RAW_DATABASE', 'raw_db') }}"
    schema: "{{ env_var('DBT_RAW_SCHEMA', 'ecommerce') }}"
```

## Related

- [refs.md](refs.md)
- [tests.md](tests.md)
- [project-structure.md](../patterns/project-structure.md)
