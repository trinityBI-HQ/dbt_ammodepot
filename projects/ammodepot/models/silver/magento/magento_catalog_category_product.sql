{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}
select * 
from {{ source('magento','catalog_category_product') }}
