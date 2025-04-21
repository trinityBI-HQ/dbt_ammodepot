{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        id,
        shipid,
        cartonnum,
        weight,
        freightweight,
        freightamount,
        trackingnum,
        cartonid,
        customfields,
        datecreated,
        datelastmodified
    FROM 
        {{ source('fishbowl', 'shipcarton') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS ship_carton_id,
    shipid AS shipment_id,
    cartonnum AS carton_number,
    weight AS carton_weight,
    freightweight AS freight_weight,
    freightamount AS freight_amount,
    trackingnum AS tracking_number,
    cartonid AS carton_id,
    customfields AS custom_fields,
    datecreated AS date_created,
    datelastmodified AS date_last_modified
FROM 
    source_data
