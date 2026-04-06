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
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    link_id,
    product_id,
    parent_id
from source_data
