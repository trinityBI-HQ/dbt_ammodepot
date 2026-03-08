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
    qualify
        row_number() over (
            partition by value_id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    value_id,
    entity_id,
    attribute_id,
    store_id,
    value
from source_data
