{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}
select *
from {{ ref('magento_store') }}