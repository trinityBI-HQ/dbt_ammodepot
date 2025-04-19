{{ config(materialized='table') }}

with raw_orders as (
  select * from {{ source('bronze','bronze_test') }}
)

select
  id as bronze_test_id,
  user_id,
  cast(amount as numeric)      as amount,
  cast(created_at as timestamp) as order_ts
from raw_orders