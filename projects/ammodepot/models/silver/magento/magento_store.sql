{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (

    select
        store_id,
        name,
        code,
        group_id,
        website_id,
        is_active,
        sort_order,
        _ab_cdc_deleted_at

    from
        {{ source('magento', 'store') }}
    where
        _ab_cdc_deleted_at is null
)

select
    store_id as store_id,
    name as store_name,
    code as store_code,
    group_id as group_id,
    website_id as website_id,
    CAST(is_active as BOOLEAN) as is_active,
    sort_order as sort_order

from
    source_data
