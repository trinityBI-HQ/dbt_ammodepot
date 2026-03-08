with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'parttracking') }}
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
    id as part_tracking_id,         -- Renamed primary key for this part tracking type definition
    typeid as part_tracking_type_id,-- Further classification of the tracking type

    -- Tracking Type Details
    name as part_tracking_name,
    abbr as part_tracking_abbreviation,
    description as part_tracking_description,
    gs1code as gs1_code,              -- GS1 standard code, if applicable
    sortorder as sort_order,

    -- Status
    CAST(activeflag as BOOLEAN) as is_active,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
