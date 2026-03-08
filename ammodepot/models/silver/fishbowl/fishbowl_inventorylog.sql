with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'inventorylog') }}
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
    id as inventory_log_id,         -- Renamed primary key
    partid as part_id,              -- Foreign key to part
    userid as user_id,              -- User performing the action
    typeid as log_type_id,          -- Type of inventory log event
    tableid as related_table_id,    -- ID of the table related to the event (e.g., SO, PO)
    recordid as related_record_id,  -- Record ID in the related table
    parttrackingid as part_tracking_id, -- If part tracking is used

    -- Quantity & Cost
    changeqty as quantity_changed,
    qtyonhand as quantity_on_hand_after_change,
    cost as cost_of_change, -- Cost associated with this specific change (e.g., if it's a receipt)

    -- Location & Tags
    beglocationid as beginning_location_id,
    endlocationid as ending_location_id,
    locationgroupid as location_group_id,
    begtagnum as beginning_tag_number,
    endtagnum as ending_tag_number,

    -- Timestamps
    eventdate as event_timestamp,   -- Timestamp of the inventory event
    datecreated as record_created_at, -- Timestamp when this log record was created

    -- Other
    info as log_info,               -- Additional information/notes

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
