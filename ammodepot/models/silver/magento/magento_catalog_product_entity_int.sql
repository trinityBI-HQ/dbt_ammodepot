with source_data as (

    select
        value_id,
        entity_id,
        attribute_id,
        store_id,
        value
    from {{ source('magento', 'catalog_product_entity_int') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by value_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    value_id,
    entity_id,
    attribute_id,
    store_id,
    value
from source_data
