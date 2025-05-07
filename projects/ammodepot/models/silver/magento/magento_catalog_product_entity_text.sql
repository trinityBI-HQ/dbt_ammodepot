{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}
select * 
from {{ source('magento','catalog_product_entity_text') }}
