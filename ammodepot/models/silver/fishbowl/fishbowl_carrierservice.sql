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
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
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
