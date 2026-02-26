{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (
    -- This CTE selects all columns from the source view
    select
        abbr,
        name,
        tagid,
        typeid,
        serialid,
        serialnum,
        sortorder,
        activeflag,
        description,
        serialnumid,
        committedflag,
        parttrackingid

        -- Airbyte internal columns are excluded as they are not relevant for a view source
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'tagserialview') }}
    -- No WHERE clause for _ab_cdc_deleted_at as this is likely a view
)

select
    -- Identifiers (from the view)
    tagid as tag_id,
    serialid as serial_id,              -- Likely the ID from the SERIAL table
    serialnumid as serial_num_record_id, -- Likely the ID from the SERIALNUM table
    parttrackingid as part_tracking_id, -- ID of the part tracking definition

    -- Serial Number Details
    serialnum as serial_number_value,

    -- Part Tracking Details (denormalized from PARTTRACKING via the view)
    name as part_tracking_name,
    abbr as part_tracking_abbreviation,
    description as part_tracking_description,
    typeid as part_tracking_type_id,
    sortorder as part_tracking_sort_order,
    CAST(activeflag as BOOLEAN) as is_part_tracking_active,

    -- Serial Number Status (denormalized from SERIAL via the view)
    CAST(committedflag as BOOLEAN) as is_serial_committed

from
    source_data
