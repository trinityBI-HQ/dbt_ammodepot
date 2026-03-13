---
paths:
  - projects/**/models/**/*.sql
  - projects/**/macros/**/*.sql
---

# SQL Standards

> **Source**: https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql

## Formatting

- **Line length**: 80 characters max
- **Indentation**: 4 spaces (not tabs)
- **Capitalization**: All lowercase for field names, keywords, function names
- **Aliases**: Always use explicit `as` keyword for field and table aliases
- **Commas**: Trailing commas (end of line)
- **Comments**: Use Jinja comments (`{# #}`) for notes that shouldn't appear in compiled SQL
- **Linting**: Use SQLFluff to enforce rules automatically; reference `.sqlfluff` config

## Column Selection (ABSOLUTE RULE)

- **Every model MUST use explicit column lists** — `SELECT *` is forbidden
- Applies to ALL layers: Bronze, Silver, Gold
- Applies to ALL CTEs including import CTEs
- The ONLY acceptable `SELECT *` is `select * from final` as the very last statement (selecting from a CTE where columns are already explicitly listed)
- When referencing another model via `ref()` or `source()`, always list the columns you need
- **Why**: Schema drift silently propagates, column-level lineage breaks, unnecessary columns waste compute, and explicit columns document the model's contract

## Fields, Aggregations, and Grouping

- **Field order**: Place fields before aggregates and window functions in SELECT
- **Aggregation timing**: Aggregate early on the smallest dataset before joining to improve performance
- **Grouping syntax**: Prefer `group by 1, 2` (numeric) over column names; many group-by columns suggests reconsidering model design

## Joins

- **Explicit types**: Always write `inner join`, `left join` — never bare `join`
- **No right joins**: If you need a right join, swap the `from` and `join` tables
- **Column prefixes**: Always prefix columns with table/CTE name when joining multiple tables
- **No aliases**: Use full descriptive CTE names (`customers` not `c`)
- **Join direction**: Left-to-right reading — `left_table.id = right_table.id`
- **Union**: Prefer `union all` over `union` unless explicitly removing duplicates

## Import CTEs

- Place ALL `{{ ref('...') }}` and `{{ source('...') }}` statements in CTEs at the top of the file
- Name import CTEs after the table they reference
- Select only columns needed downstream (explicit column lists, never `SELECT *`)
- Do NOT select columns that are only used in `WHERE`, `ON`, or `HAVING` clauses — those columns are available for filtering without being in the `SELECT` list
- Filter with `where` clauses in import CTEs to minimize scanned data

```sql
-- CORRECT: region is used in WHERE but not selected
-- (not needed downstream)
with orders as (
    select
        order_id,
        customer_id,
        order_total,
        order_date
    from {{ ref('stg_ecommerce__orders') }}
    where region = 'US'
),
```

## Functional CTEs

- Where performance permits, CTEs should perform a single, logical unit of work
- CTE names should be as verbose as needed to convey what they do (e.g., `events_joined_to_users` not `user_events`)
- If a CTE is duplicated across models, extract it into a separate intermediate model
- **The last line of a model should be `select * from final`** — this makes it easy to materialize and audit the output from different steps in the model as you're developing it. You just change the CTE referenced in the select statement to see the output from that step. This is the ONE acceptable use of `SELECT *`

## Model Configuration

- Use `config()` block at top of model for model-specific settings
- Use `dbt_project.yml` for directory-level defaults
- Format config blocks with one parameter per line:

```sql
{{
    config(
        materialized = 'table',
        sort = 'id',
        dist = 'id'
    )
}}
```

## Complete Reference Example

```sql
with my_data as (
    select
        field_1,
        field_2,
        field_3,
        cancellation_date,
        expiration_date,
        start_date
    from {{ ref('my_data') }}
),

some_cte as (
    select
        id,
        field_4,
        field_5
    from {{ ref('some_cte') }}
),

some_cte_agg as (
    select
        id,
        sum(field_4) as total_field_4,
        max(field_5) as max_field_5
    from some_cte
    group by 1
),

joined as (
    select
        my_data.field_1,
        my_data.field_2,
        my_data.field_3,
        case
            when my_data.cancellation_date is null
                and my_data.expiration_date is not null
                then expiration_date
            when my_data.cancellation_date is null
                then my_data.start_date + 7
            else my_data.cancellation_date
        end as cancellation_date,
        some_cte_agg.total_field_4,
        some_cte_agg.max_field_5
    from my_data
    left join some_cte_agg
        on my_data.id = some_cte_agg.id
    where my_data.field_1 = 'abc'
        and (
            my_data.field_2 = 'def'
            or my_data.field_2 = 'ghi'
        )
    having count(*) > 1
)

select * from joined
```
