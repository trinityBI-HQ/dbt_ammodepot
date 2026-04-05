with source_data as (

    select
        value_id,
        entity_id,
        attribute_id,
        store_id,
        value
    from {{ source('magento', 'catalog_product_entity_text') }}
    where
        _ab_cdc_deleted_at is null
)

select
    value_id,
    entity_id,
    attribute_id,
    store_id,
    value
from source_data
