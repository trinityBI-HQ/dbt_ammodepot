{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}


select *
FROM {{ source('fishbowl', 'vendorparts') }}