{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (

    select
        -- Core Business Columns
        id,
        activeflag,
        carrierid,
        code,
        name,
        readonly

    from
        -- Source is defined in DDL as PC_FIVETRAN_DB.FB_TESTING1234.CARRIERSERVICE
        -- Adjust 'fishbowl_fivetran' if your source name for this schema is different
        {{ source('fishbowl', 'carrierservice') }}

)

select
    id as carrier_service_id,          -- Renamed primary key
    carrierid as carrier_id,           -- Renamed foreign key
    code as carrier_service_code,      -- Renamed for clarity
    name as carrier_service_name,      -- Renamed for clarity
    CAST(activeflag as BOOLEAN) as is_active, -- Cast and rename flag
    CAST(readonly as BOOLEAN) as is_readonly -- Cast and rename flag

from
    source_data
