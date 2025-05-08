{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (
    -- This CTE selects all columns from the source view
    SELECT
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
    FROM
        {{ source('fishbowl', 'tagserialview') }}
    -- No WHERE clause for _ab_cdc_deleted_at as this is likely a view
)

SELECT
    -- Identifiers (from the view)
    tagid AS tag_id,
    serialid AS serial_id,              -- Likely the ID from the SERIAL table
    serialnumid AS serial_num_record_id, -- Likely the ID from the SERIALNUM table
    parttrackingid AS part_tracking_id, -- ID of the part tracking definition

    -- Serial Number Details
    serialnum AS serial_number_value,

    -- Part Tracking Details (denormalized from PARTTRACKING via the view)
    name AS part_tracking_name,
    abbr AS part_tracking_abbreviation,
    description AS part_tracking_description,
    typeid AS part_tracking_type_id,
    sortorder AS part_tracking_sort_order,
    CAST(activeflag AS BOOLEAN) AS is_part_tracking_active,

    -- Serial Number Status (denormalized from SERIAL via the view)
    CAST(committedflag AS BOOLEAN) AS is_serial_committed

FROM
    source_data