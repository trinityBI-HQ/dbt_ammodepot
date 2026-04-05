with source_data as (

    select
        attribute_id,
        attribute_code
    from {{ source('magento', 'eav_attribute') }}
    where
        _ab_cdc_deleted_at is null
)

select
    attribute_id,
    attribute_code
from source_data
