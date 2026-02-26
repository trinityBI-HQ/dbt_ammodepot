with source_data as (

    select
        attribute_id,
        attribute_code
    from {{ source('magento', 'eav_attribute') }}

)

select
    attribute_id,
    attribute_code
from source_data
