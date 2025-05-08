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
        name,
        typeid,
        parentid,
        pickable,
        sortorder,
        activeflag,
        receivable,
        defaultflag,
        description,
        customfields,
        defaultvendorid,
        locationgroupid,
        datelastmodified,
        defaultcustomerid,
        countedasavailable,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'location') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS location_id,              -- Renamed primary key
    parentid AS parent_location_id, -- Foreign key for hierarchical locations
    locationgroupid AS location_group_id, -- Foreign key to locationgroup

    -- Location Details
    name AS location_name,
    description AS location_description,
    typeid AS location_type_id,
    sortorder AS sort_order,

    -- Flags
    CAST(activeflag AS BOOLEAN) AS is_active,
    CAST(defaultflag AS BOOLEAN) AS is_default_location,
    CAST(pickable AS BOOLEAN) AS is_pickable,
    CAST(receivable AS BOOLEAN) AS is_receivable,
    CAST(countedasavailable AS BOOLEAN) AS is_counted_as_available, -- Assuming this is a boolean flag

    -- Defaults
    defaultvendorid AS default_vendor_id,
    defaultcustomerid AS default_customer_id,

    -- Custom Fields
    customfields AS custom_fields,  -- Typically JSON or serialized string

    -- Timestamps
    datelastmodified AS last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data