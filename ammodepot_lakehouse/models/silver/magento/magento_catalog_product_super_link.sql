with source_data as (

    select
        link_id,
        product_id,
        parent_id
    from {{ source('magento', 'catalog_product_super_link') }}
    where
        _ab_cdc_deleted_at is null
)

select
    link_id,
    product_id,
    parent_id
from source_data
