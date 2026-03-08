with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        partid,
        nextvalue,
        primaryflag,
        parttrackingid,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'parttotracking') }}
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
    id as part_to_tracking_id,          -- Renamed primary key for this mapping record
    partid as part_id,                  -- Foreign key to the PART table
    parttrackingid as part_tracking_id, -- Foreign key to the PARTTRACKING table

    -- Tracking Configuration
    nextvalue as next_tracking_value,    -- Next value to be used for this tracking type for this part
    CAST(primaryflag as BOOLEAN) as is_primary_tracking, -- Flag indicating if this is the primary tracking for the part

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
