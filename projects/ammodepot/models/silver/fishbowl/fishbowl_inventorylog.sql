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
        cost,
        info,
        partid,
        typeid,
        userid,
        tableid,
        recordid,
        begtagnum,
        changeqty,
        endtagnum,
        eventdate,
        qtyonhand,
        datecreated,
        beglocationid,
        endlocationid,
        parttrackingid,
        locationgroupid,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'inventorylog') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS inventory_log_id,         -- Renamed primary key
    partid AS part_id,              -- Foreign key to part
    userid AS user_id,              -- User performing the action
    typeid AS log_type_id,          -- Type of inventory log event
    tableid AS related_table_id,    -- ID of the table related to the event (e.g., SO, PO)
    recordid AS related_record_id,  -- Record ID in the related table
    parttrackingid AS part_tracking_id, -- If part tracking is used

    -- Quantity & Cost
    changeqty AS quantity_changed,
    qtyonhand AS quantity_on_hand_after_change,
    cost AS cost_of_change, -- Cost associated with this specific change (e.g., if it's a receipt)

    -- Location & Tags
    beglocationid AS beginning_location_id,
    endlocationid AS ending_location_id,
    locationgroupid AS location_group_id,
    begtagnum AS beginning_tag_number,
    endtagnum AS ending_tag_number,

    -- Timestamps
    eventdate AS event_timestamp,   -- Timestamp of the inventory event
    datecreated AS record_created_at, -- Timestamp when this log record was created

    -- Other
    info AS log_info,               -- Additional information/notes

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data