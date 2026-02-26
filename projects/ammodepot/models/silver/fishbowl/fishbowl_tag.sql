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
        num,
        qty,
        partid,
        typeid,
        usedflag,
        woitemid,
        locationid,
        datecreated,
        qtycommitted,
        serializedflag,
        datelastmodified,
        trackingencoding,
        datelastcyclecount,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'tag') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as tag_id,                   -- Renamed primary key for this tag record
    partid as part_id,              -- Foreign key to the PART table
    locationid as location_id,      -- Foreign key to the LOCATION table where this tag exists
    woitemid as work_order_item_id, -- Foreign key to Work Order Item (if applicable)

    -- Tag Details
    num as tag_number,              -- The actual tag number/identifier string
    typeid as tag_type_id,          -- Type of tag (e.g., inventory, asset)

    -- Quantity
    qty as quantity_on_tag,
    qtycommitted as quantity_committed_on_tag,

    -- Flags
    CAST(usedflag as BOOLEAN) as is_used, -- Flag indicating if the tag is currently in use
    CAST(serializedflag as BOOLEAN) as is_serialized_item_on_tag, -- Flag if the item(s) on this tag are serialized

    -- Tracking
    trackingencoding as tracking_encoding, -- Encoding method for tracking information if applicable

    -- Timestamps
    datecreated as created_at,
    datelastmodified as last_modified_at,
    datelastcyclecount as last_cycle_count_date,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
