{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (
    -- This CTE selects all relevant columns from the source
    SELECT
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
    FROM
        {{ source('fishbowl', 'xo') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS transfer_order_id,        -- Renamed primary key
    num AS transfer_order_number,   -- User-facing Transfer Order number
    userid AS user_id,              -- User who created/managed the TO

    -- Transfer Order Details
    typeid AS transfer_order_type_id,
    statusid AS status_id,
    revisionnum AS revision_number,
    carrierid AS carrier_id,
    carrierserviceid AS carrier_service_id,
    CAST(ownerisfrom AS BOOLEAN) AS owner_is_from_location, -- Flag indicating ownership transfer point

    -- From Location Details
    fromlgid AS from_location_group_id,
    fromname AS from_location_name,
    fromaddress AS from_address,
    fromcity AS from_city,
    fromstateid AS from_state_id,
    fromzip AS from_zip_code,
    fromcountryid AS from_country_id,
    fromattn AS from_attention,

    -- To Location Details
    shiptolgid AS to_location_group_id, -- "Ship To" is essentially "Transfer To"
    shiptoname AS to_location_name,
    shiptoaddress AS to_address,
    shiptocity AS to_city,
    shiptostateid AS to_state_id,
    shiptozip AS to_zip_code,
    shiptocountryid AS to_country_id,
    shiptoattn AS to_attention,
    mainlocationtagid AS main_to_location_tag_id, -- Tag ID for the destination main location

    -- Timestamps
    datecreated AS created_at,
    datelastmodified AS last_modified_at,
    dateissued AS issued_at,
    dateconfirmed AS confirmed_at,
    datecompleted AS completed_at,
    datescheduled AS scheduled_transfer_date,
    datefirstship AS first_shipment_date, -- Date of the first shipment against this TO

    -- Other
    note AS transfer_order_note,
    customfields AS custom_fields,      -- Typically JSON or serialized string

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data