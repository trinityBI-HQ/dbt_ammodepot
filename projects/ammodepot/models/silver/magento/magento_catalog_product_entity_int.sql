with source_data as (

    select
        entity_id,
        attribute_id,
        store_id,
        value
    from {{ source('magento', 'catalog_product_entity_int') }}

)

select
    entity_id,
    attribute_id,
    store_id,
    value
from source_data
