{{ config(materialized='table') }}

with combined_orders as (
  select * from {{ ref('dbt_test_silver') }}
  union all
  select * from {{ ref('dbt_test_silver2') }}
)

select
  user_id,
  count(*)     as total_orders,
  sum(amount)  as total_amount
from combined_orders
group by user_id