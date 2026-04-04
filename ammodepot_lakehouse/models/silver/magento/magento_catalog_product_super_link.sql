with source_data as (

    select
        link_id,
        product_id,
        parent_id
    from {{ source('magento', 'catalog_product_super_link') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by link_id
            order by coalesce(try_cast(_ab_cdc_updated_at as timestamp), epoch_ms(_airbyte_extracted_at)) desc nulls last
        ) = 1
)

select
    link_id,
    product_id,
    parent_id
from source_data
