with source_data as (

    select
        value_id,
        entity_id,
        attribute_id,
        value
    from {{ source('magento', 'catalog_category_entity_varchar') }}

)

select
    value_id,
    entity_id,
    attribute_id,
    value
from source_data
