with source_data as (

    select
        entity_id,
        attribute_id,
        value
    from {{ source('magento', 'catalog_category_entity_varchar') }}

)

select
    entity_id,
    attribute_id,
    value
from source_data
