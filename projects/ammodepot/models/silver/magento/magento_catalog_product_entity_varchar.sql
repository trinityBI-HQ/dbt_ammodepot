{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}
select * 
from {{ source('magento','catalog_product_entity_varchar') }}
