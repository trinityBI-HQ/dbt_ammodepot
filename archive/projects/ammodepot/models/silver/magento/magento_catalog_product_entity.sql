with source_data as (
    select 
        entity_id,
        attribute_set_id,
        type_id,
        sku,
        has_options,
        required_options,
        created_at,
        updated_at
    from 
        {{ source('magento', 'catalog_product_entity') }}
    where 
        _ab_cdc_deleted_at is null
)

select 
    entity_id as product_entity_id,
    attribute_set_id,
    type_id,
    sku,
    CAST(has_options as BOOLEAN) as has_options,
    CAST(required_options as BOOLEAN) as required_options,
    created_at,
    updated_at
from 
    source_data
