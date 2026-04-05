with source_data as (

    select
        entity_id,
        product_id,
        category_id
    from {{ source('magento', 'catalog_category_product') }}
    where
        _ab_cdc_deleted_at is null
)

select
    entity_id,
    product_id,
    category_id
from source_data
