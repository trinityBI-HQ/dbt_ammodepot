{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}
select * 
from {{ source('magento','eav_attribute') }}
