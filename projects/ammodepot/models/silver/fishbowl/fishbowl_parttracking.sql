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
        abbr,
        name,
        typeid,
        gs1code,
        sortorder,
        activeflag,
        description,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'parttracking') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS part_tracking_id,         -- Renamed primary key for this part tracking type definition
    typeid AS part_tracking_type_id,-- Further classification of the tracking type

    -- Tracking Type Details
    name AS part_tracking_name,
    abbr AS part_tracking_abbreviation,
    description AS part_tracking_description,
    gs1code AS gs1_code,              -- GS1 standard code, if applicable
    sortorder AS sort_order,

    -- Status
    CAST(activeflag AS BOOLEAN) AS is_active,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data