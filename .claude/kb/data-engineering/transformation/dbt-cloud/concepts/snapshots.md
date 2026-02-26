# Snapshots

> **Purpose**: SCD Type 2 historical tracking of mutable source data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Snapshots capture changes to mutable tables over time, implementing Slowly Changing Dimension (SCD) Type 2 patterns. They track when records change by adding `dbt_valid_from`, `dbt_valid_to`, and `dbt_scd_id` columns. Two strategies exist: timestamp (preferred) and check.

## Timestamp Strategy

```sql
-- snapshots/snap_customers.sql
{% snapshot snap_customers %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at',
      invalidate_hard_deletes=True
    )
}}

select * from {{ source('raw', 'customers') }}

{% endsnapshot %}
```

## Check Strategy

```sql
-- snapshots/snap_products.sql
{% snapshot snap_products %}

{{
    config(
      target_schema='snapshots',
      unique_key='product_id',
      strategy='check',
      check_cols=['name', 'price', 'category']
    )
}}

select * from {{ source('raw', 'products') }}

{% endsnapshot %}
```

## Strategy Comparison

| Strategy | Use When | Pros | Cons |
|----------|----------|------|------|
| `timestamp` | Reliable `updated_at` exists | Efficient, precise | Needs timestamp |
| `check` | No timestamp available | Works anywhere | Slower, more storage |

## Generated Columns

| Column | Purpose |
|--------|---------|
| `dbt_scd_id` | Unique ID for each version |
| `dbt_valid_from` | When this version became valid |
| `dbt_valid_to` | When this version was superseded |
| `dbt_updated_at` | Source timestamp (timestamp strategy) |

## Configuration Options

```sql
{{
    config(
      dbt_valid_to_current="'9999-12-31'::timestamp"
    )
}}
-- Sets dbt_valid_to to specific value instead of NULL for current records
```

## Common Mistakes

### Wrong

```sql
-- Non-unique key causes duplicates
unique_key='name'  -- Names can repeat!
```

### Correct

```sql
-- Truly unique identifier
unique_key='customer_id'
```

## Related

- [Incremental Models](../patterns/incremental-models.md)
- [sources-seeds](sources-seeds.md)
