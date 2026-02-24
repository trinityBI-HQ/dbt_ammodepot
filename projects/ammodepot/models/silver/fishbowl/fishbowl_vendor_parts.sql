{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}


select *
from {{ source('fishbowl', 'vendorparts') }}
