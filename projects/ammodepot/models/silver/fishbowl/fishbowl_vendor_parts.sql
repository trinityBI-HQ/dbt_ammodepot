{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}


select *
FROM {{ source('fishbowl', 'vendorparts') }}