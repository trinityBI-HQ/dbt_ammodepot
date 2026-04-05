with source_data as (

    select
        attribute_set_id,
        attribute_set_name
    from {{ source('magento', 'eav_attribute_set') }}
    where
        _ab_cdc_deleted_at is null
)

select
    attribute_set_id,
    attribute_set_name
from source_data
