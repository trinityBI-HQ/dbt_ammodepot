# Project Structure Pattern

> **Purpose**: Organize dbt projects with staging, intermediate, and marts layers
> **Source**: https://docs.getdbt.com/best-practices/how-we-structure
> **MCP Validated**: 2026-02-19

## When to Use

- Starting a new dbt project
- Refactoring a monolithic SQL codebase
- Scaling a project with multiple data sources

## Implementation

```text
my_dbt_project/
├── dbt_project.yml
├── packages.yml
├── models/
│   ├── staging/                          # 1:1 with sources, organized by source system
│   │   ├── stripe/
│   │   │   ├── _stripe__sources.yml
│   │   │   ├── _stripe__models.yml
│   │   │   ├── _stripe__docs.md
│   │   │   ├── base/                     # Optional: for joins/unions before staging
│   │   │   │   └── base_stripe__charges.sql
│   │   │   └── stg_stripe__payments.sql
│   │   └── jaffle_shop/
│   │       ├── _jaffle_shop__sources.yml
│   │       └── stg_jaffle_shop__orders.sql
│   ├── intermediate/                     # Organized by business function
│   │   └── finance/
│   │       └── int_payments_pivoted_to_orders.sql
│   └── marts/                            # Organized by department
│       ├── finance/
│       │   └── orders.sql
│       └── marketing/
│           └── customers.sql
├── macros/
├── snapshots/
├── seeds/
├── functions/                            # User-defined functions (v1.11+)
│   └── my_udf.sql
└── tests/
    └── generic/                          # Custom generic tests
```

## Configuration

```yaml
# dbt_project.yml
name: 'my_project'
version: '1.0.0'
config-version: 2

models:
  my_project:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      +schema: marts
```

## Naming Conventions

| Layer | Convention | Example | Notes |
|-------|-----------|---------|-------|
| Staging | `stg_[source]__[entity]s` | `stg_stripe__payments` | Double underscore separates source from entity; plural |
| Intermediate | `int_[entity]s_[verb]s` | `int_payments_pivoted_to_orders` | Verb describes transformation |
| Marts | Plain entity name | `orders`, `customers` | No prefix needed; plural |
| Snapshot | `snp_` | `snp_customers` | SCD Type 2 history |
| Supporting files | `_[source]__[type]` | `_stripe__sources.yml` | Leading underscore groups with models |

## Staging Layer

**Rule**: One staging model per source table. `source()` macro only appears here.

Allowed: rename, type cast, basic math (cents→dollars), CASE WHEN categorization.
Forbidden: joins, aggregations (move to intermediate).

```sql
-- models/staging/stripe/stg_stripe__payments.sql
with source as (
    select * from {{ source('stripe', 'payment') }}
),
renamed as (
    select
        ---------- ids
        id as payment_id,
        orderid as order_id,
        ---------- strings
        paymentmethod as payment_method,
        case
            when payment_method in ('stripe', 'paypal', 'credit_card')
            then 'credit'
            else 'cash'
        end as payment_type,
        ---------- numerics
        amount / 100.0 as amount,
        ---------- timestamps
        created::timestamp_ltz as created_at
    from source
)
select * from renamed
```

## Intermediate Layer

Organize by business function. Use for: simplifying joins (4-6 staging models), re-graining, isolating complexity.

```sql
-- models/intermediate/finance/int_payments_pivoted_to_orders.sql
with payments as (
    select * from {{ ref('stg_stripe__payments') }}
),
pivoted as (
    select
        order_id,
        sum(case when payment_type = 'credit' then amount else 0 end) as credit_amount,
        sum(case when payment_type = 'cash' then amount else 0 end) as cash_amount,
        sum(amount) as total_amount
    from payments
    group by 1
)
select * from pivoted
```

## Marts Layer

Wide, denormalized entities. Limit to 4-5 joins; use intermediate models beyond that.

```sql
-- models/marts/finance/orders.sql
with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),
payments as (
    select * from {{ ref('int_payments_pivoted_to_orders') }}
),
final as (
    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        payments.credit_amount,
        payments.cash_amount,
        payments.total_amount
    from orders
    left join payments on orders.order_id = payments.order_id
)
select * from final
```

## Example Usage

```bash
dbt run --select staging      # Run all staging models
dbt run --select +fct_orders  # Run mart with dependencies
dbt build --select marts      # Build with tests
```

## Folder Organization Rules

| Layer | Organize By | Rationale |
|-------|------------|-----------|
| Staging | Source system | Shared loading methods; enables `dbt build --select staging.stripe+` |
| Intermediate | Business function | Cross-source transformations grouped by domain |
| Marts | Department | Skip subfolders if <10 marts |

## See Also

- [best-practices.md](best-practices.md)
- [style-guide.md](style-guide.md)
- [../concepts/materializations.md](../concepts/materializations.md)
