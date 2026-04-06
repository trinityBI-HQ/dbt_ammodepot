with source_data as (

    select
        attribute_id,
        attribute_code
    from {{ source('magento', 'eav_attribute') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by attribute_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    attribute_id,
    attribute_code
from source_data
