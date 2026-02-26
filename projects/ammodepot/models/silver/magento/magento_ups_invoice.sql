with source_data as (
    select
        tracking_number,
        net_amount
    from {{ source('magento', 'ups_invoice') }}
)

select
    tracking_number,
    net_amount
from source_data
