with source_data as (

    select
        value_id,
        entity_id,
        attribute_id,
        store_id,
        value
    from {{ source('magento', 'catalog_product_entity_varchar') }}

)

select
    value_id,
    entity_id,
    attribute_id,
    store_id,
    value
from source_data
