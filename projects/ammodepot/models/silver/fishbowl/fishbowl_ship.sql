{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        id,
        soid,
        carrierserviceid,
        shipdate,
        statusid,
        trackingnum,
        customfields,
        datecreated,
        datelastmodified
    FROM 
        {{ source('fishbowl', 'ship') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS shipment_id,
    soid AS so_id,
    carrierserviceid AS carrier_service_id,
    shipdate AS ship_date,
    statusid AS status_id,
    trackingnum AS tracking_number,
    customfields AS custom_fields,
    datecreated AS date_created,
    datelastmodified AS date_last_modified
FROM 
    source_data
