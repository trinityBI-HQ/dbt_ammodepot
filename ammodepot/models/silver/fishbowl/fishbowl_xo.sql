with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        num,
        note,
        typeid,
        userid,
        fromzip,
        fromattn,
        fromcity,
        fromlgid,
        fromname,
        statusid,
        carrierid,
        shiptozip,
        dateissued,
        shiptoattn,
        shiptocity,
        shiptolgid,
        shiptoname,
        datecreated,
        fromaddress,
        fromstateid,
        ownerisfrom,
        revisionnum,
        customfields,
        datecompleted,
        dateconfirmed,
        datefirstship,
        datescheduled,
        fromcountryid,
        shiptoaddress,
        shiptostateid,
        shiptocountryid,
        carrierserviceid,
        datelastmodified,
        mainlocationtagid,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'xo') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    -- Identifiers
    id as transfer_order_id,        -- Renamed primary key
    num as transfer_order_number,   -- User-facing Transfer Order number
    userid as user_id,              -- User who created/managed the TO

    -- Transfer Order Details
    typeid as transfer_order_type_id,
    statusid as status_id,
    revisionnum as revision_number,
    carrierid as carrier_id,
    carrierserviceid as carrier_service_id,
    CAST(ownerisfrom as BOOLEAN) as owner_is_from_location, -- Flag indicating ownership transfer point

    -- From Location Details
    fromlgid as from_location_group_id,
    fromname as from_location_name,
    fromaddress as from_address,
    fromcity as from_city,
    fromstateid as from_state_id,
    fromzip as from_zip_code,
    fromcountryid as from_country_id,
    fromattn as from_attention,

    -- To Location Details
    shiptolgid as to_location_group_id, -- "Ship To" is essentially "Transfer To"
    shiptoname as to_location_name,
    shiptoaddress as to_address,
    shiptocity as to_city,
    shiptostateid as to_state_id,
    shiptozip as to_zip_code,
    shiptocountryid as to_country_id,
    shiptoattn as to_attention,
    mainlocationtagid as main_to_location_tag_id, -- Tag ID for the destination main location

    -- Timestamps
    datecreated as created_at,
    datelastmodified as last_modified_at,
    dateissued as issued_at,
    dateconfirmed as confirmed_at,
    datecompleted as completed_at,
    datescheduled as scheduled_transfer_date,
    datefirstship as first_shipment_date, -- Date of the first shipment against this TO

    -- Other
    note as transfer_order_note,
    customfields as custom_fields,      -- Typically JSON or serialized string

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
