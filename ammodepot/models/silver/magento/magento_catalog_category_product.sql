with source_data as (

    select
        entity_id,
        product_id,
        category_id
    from {{ source('magento', 'catalog_category_product') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by entity_id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    entity_id,
    product_id,
    category_id
from source_data
