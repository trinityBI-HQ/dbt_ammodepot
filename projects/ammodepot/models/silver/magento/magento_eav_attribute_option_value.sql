with source_data as (

    select
        option_id,
        store_id,
        value
    from {{ source('magento', 'eav_attribute_option_value') }}

)

select
    option_id,
    store_id,
    value
from source_data
