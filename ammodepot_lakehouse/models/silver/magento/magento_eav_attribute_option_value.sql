with source_data as (

    select
        option_id,
        store_id,
        value
    from {{ source('magento', 'eav_attribute_option_value') }}
    where
        _ab_cdc_deleted_at is null
)

select
    option_id,
    store_id,
    value
from source_data
