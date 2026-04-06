with source_data as (

    select
        option_id,
        store_id,
        value
    from {{ source('magento', 'eav_attribute_option_value') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by option_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    option_id,
    store_id,
    value
from source_data
