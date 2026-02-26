with source_data as (

    select
        attribute_set_id,
        attribute_set_name
    from {{ source('magento', 'eav_attribute_set') }}

)

select
    attribute_set_id,
    attribute_set_name
from source_data
