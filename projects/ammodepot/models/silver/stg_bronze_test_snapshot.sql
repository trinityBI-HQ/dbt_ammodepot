{{ config(materialized='table') }}

select
  id,
  user_id,
  amount,
  created_at as order_ts
from {{ ref('bronze_test_snapshot') }}
