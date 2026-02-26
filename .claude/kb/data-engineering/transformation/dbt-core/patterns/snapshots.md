# Snapshots Pattern (SCD Type 2)

> **Purpose**: Track historical changes to mutable source data using Slowly Changing Dimensions
> **MCP Validated**: 2026-02-19

## When to Use

- Tracking changes to dimension tables over time
- Maintaining historical state of mutable source data
- Implementing SCD Type 2 for analytics
- Audit trails for customer/product/account changes

## Implementation

```sql
-- snapshots/snp_customers.sql
{% snapshot snp_customers %}

{{
    config(
        target_database='analytics',
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

select
    customer_id,
    customer_name,
    email,
    segment,
    status,
    updated_at
from {{ source('raw', 'customers') }}

{% endsnapshot %}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `unique_key` | Required | Column identifying each record |
| `strategy` | Required | timestamp or check |
| `updated_at` | For timestamp | Column tracking last update |
| `check_cols` | For check | Columns to monitor for changes |
| `invalidate_hard_deletes` | False | Track deleted records (dbt 1.9+) |
| `dbt_valid_to_current` | NULL | Sentinel value for current records |

## Snapshot Strategies

```sql
-- TIMESTAMP: Use updated_at column (preferred when available)
{% snapshot snp_products %}
{{
    config(
        unique_key='product_id',
        strategy='timestamp',
        updated_at='modified_at'
    )
}}
select * from {{ source('raw', 'products') }}
{% endsnapshot %}

-- CHECK: Compare specific columns (when no timestamp exists)
{% snapshot snp_accounts %}
{{
    config(
        unique_key='account_id',
        strategy='check',
        check_cols=['status', 'balance', 'account_type']
    )
}}
select * from {{ source('raw', 'accounts') }}
{% endsnapshot %}

-- CHECK ALL: Monitor all columns
{{
    config(
        unique_key='id',
        strategy='check',
        check_cols='all'
    )
}}
```

## Snapshot Output Columns

```sql
-- dbt automatically adds these columns:
select
    -- Original columns from source
    customer_id,
    customer_name,
    segment,

    -- dbt snapshot metadata
    dbt_scd_id,         -- Unique ID for each version
    dbt_updated_at,     -- When dbt captured this version
    dbt_valid_from,     -- When this version became active
    dbt_valid_to        -- When this version was superseded (NULL = current)
from analytics.snapshots.snp_customers
```

## Querying Snapshots

```sql
-- Get current state of all records
select * from {{ ref('snp_customers') }}
where dbt_valid_to is null

-- Get state as of a specific date
select * from {{ ref('snp_customers') }}
where '2024-06-15' >= dbt_valid_from
  and ('2024-06-15' < dbt_valid_to or dbt_valid_to is null)

-- Get full history for a specific customer
select * from {{ ref('snp_customers') }}
where customer_id = 'CUST-001'
order by dbt_valid_from
```

## Using Sentinel Values (dbt 1.9+)

```sql
{% snapshot snp_customers %}
{{
    config(
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        dbt_valid_to_current="to_date('9999-12-31')"  -- Instead of NULL
    )
}}
select * from {{ source('raw', 'customers') }}
{% endsnapshot %}

-- Query with sentinel value
select * from {{ ref('snp_customers') }}
where current_date between dbt_valid_from and dbt_valid_to
```

## Building Dimension from Snapshot

```sql
-- models/marts/dim_customers.sql
with snapshot_data as (
    select * from {{ ref('snp_customers') }}
),

current_records as (
    select
        customer_id,
        customer_name,
        email,
        segment,
        status,
        dbt_valid_from as effective_from
    from snapshot_data
    where dbt_valid_to is null
)

select * from current_records
```

## Example Usage

```bash
# Run all snapshots
dbt snapshot

# Run specific snapshot
dbt snapshot --select snp_customers

# Snapshots should run before models that depend on them
dbt snapshot && dbt run
```

## See Also

- [materializations.md](../concepts/materializations.md)
- [sources.md](../concepts/sources.md)
- [incremental-models.md](incremental-models.md)
