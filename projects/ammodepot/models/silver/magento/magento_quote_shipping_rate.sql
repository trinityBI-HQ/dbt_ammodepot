-- models/silver/magento/quote_shipping_rate.sql
{{ config(
    materialized = 'table',
    schema       = 'silver'
) }}

WITH source_data AS (

    SELECT
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
    FROM {{ source('magento', 'quote_shipping_rate') }}
    WHERE _ab_cdc_deleted_at IS NULL

)

SELECT
    code                             AS quote_shipping_rate_code,
    price,
    method,
    carrier,
    rate_id                          AS quote_shipping_rate_id,
    address_id                       AS quote_address_id,
    carrier_id                       AS carrier_service_id,
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
FROM source_data
