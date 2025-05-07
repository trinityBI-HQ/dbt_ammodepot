{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

select * 
from {{ source('magento','eav_attribute_set') }}
