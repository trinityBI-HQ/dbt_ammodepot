with source_data as (

    select
        code,
        price,
        method,
        carrier,
        rate_id,
        address_id,
        carrier_id,
        created_at,
        updated_at,
        carrier_type,
        carriergroup,
        method_title,
        carrier_title,
        error_message,
        carriergroup_id,
        shq_delivery_date,
        shq_dispatch_date,
        method_description,
        carriergroup_shipping_details
    from {{ source('magento', 'quote_shipping_rate') }}
    where _ab_cdc_deleted_at is null

)

select
    code                             as quote_shipping_rate_code,
    price,
    method,
    carrier,
    rate_id                          as quote_shipping_rate_id,
    address_id                       as quote_address_id,
    carrier_id                       as carrier_service_id,
    created_at,
    updated_at,
    carrier_type,
    carriergroup,
    method_title,
    carrier_title,
    error_message,
    carriergroup_id,
    shq_delivery_date,
    shq_dispatch_date,
    method_description,
    carriergroup_shipping_details
from source_data
