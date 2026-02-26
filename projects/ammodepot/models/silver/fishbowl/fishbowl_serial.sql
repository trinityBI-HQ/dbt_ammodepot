{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        tagid,
        committedflag,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'serial') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as serial_id,                -- Renamed primary key (this might be the same as SERIALNUM.SERIALID)
    tagid as tag_id,                -- Foreign key to TAG table (if applicable)

    -- Status
    CAST(committedflag as BOOLEAN) as is_committed, -- Flag indicating if the serial number is committed to an order/process

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
