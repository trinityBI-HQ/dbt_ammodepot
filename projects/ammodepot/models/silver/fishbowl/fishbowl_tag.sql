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
    FROM
        {{ source('fishbowl', 'tag') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS tag_id,                   -- Renamed primary key for this tag record
    partid AS part_id,              -- Foreign key to the PART table
    locationid AS location_id,      -- Foreign key to the LOCATION table where this tag exists
    woitemid AS work_order_item_id, -- Foreign key to Work Order Item (if applicable)

    -- Tag Details
    num AS tag_number,              -- The actual tag number/identifier string
    typeid AS tag_type_id,          -- Type of tag (e.g., inventory, asset)

    -- Quantity
    qty AS quantity_on_tag,
    qtycommitted AS quantity_committed_on_tag,

    -- Flags
    CAST(usedflag AS BOOLEAN) AS is_used, -- Flag indicating if the tag is currently in use
    CAST(serializedflag AS BOOLEAN) AS is_serialized_item_on_tag, -- Flag if the item(s) on this tag are serialized

    -- Tracking
    trackingencoding AS tracking_encoding, -- Encoding method for tracking information if applicable

    -- Timestamps
    datecreated AS created_at,
    datelastmodified AS last_modified_at,
    datelastcyclecount AS last_cycle_count_date,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data