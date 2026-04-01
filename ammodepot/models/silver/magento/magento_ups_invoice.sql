with source_data as (
    select
        tracking_number,
        net_amount
    from {{ source('ups', 'ups_invoice') }}
)

select
    tracking_number,
    net_amount
from source_data
