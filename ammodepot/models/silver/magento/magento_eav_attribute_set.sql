with source_data as (

    select
        attribute_set_id,
        attribute_set_name
    from {{ source('magento', 'eav_attribute_set') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by attribute_set_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    attribute_set_id,
    attribute_set_name
from source_data
