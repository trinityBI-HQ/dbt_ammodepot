{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Core Business Columns
        id,
        activeflag,
        carrierid,
        code,
        name,
        readonly

    FROM
        -- Source is defined in DDL as PC_FIVETRAN_DB.FB_TESTING1234.CARRIERSERVICE
        -- Adjust 'fishbowl_fivetran' if your source name for this schema is different
        {{ source('fishbowl', 'carrierservice') }}

)

SELECT
    id AS carrier_service_id,          -- Renamed primary key
    carrierid AS carrier_id,           -- Renamed foreign key
    code AS carrier_service_code,      -- Renamed for clarity
    name AS carrier_service_name,      -- Renamed for clarity
    CAST(activeflag AS BOOLEAN) AS is_active, -- Cast and rename flag
    CAST(readonly AS BOOLEAN) AS is_readonly -- Cast and rename flag

FROM
    source_data