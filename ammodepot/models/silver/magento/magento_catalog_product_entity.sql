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
    qualify
        row_number() over (
            partition by entity_id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    entity_id as product_entity_id,
    attribute_set_id,
    type_id,
    sku,
    cast(has_options as boolean) as has_options,
    cast(required_options as boolean) as required_options,
    created_at,
    updated_at
from
    source_data
