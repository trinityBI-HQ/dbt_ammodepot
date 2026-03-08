with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        note,
        xoid,
        uomid,
        partid,
        typeid,
        partnum,
        lineitem,
        statusid,
        qtypicked,
        totalcost,
        description,
        revisionnum,
        qtyfulfilled,
        qtytofulfill,
        datelastfulfillment,
        datescheduledfulfillment,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'xoitem') }}
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
    id as xo_item_id,               -- Renamed primary key for this Transfer Order item
    xoid as transfer_order_id,      -- Foreign key to the XO table
    partid as part_id,              -- Foreign key to the PART table
    lineitem as line_item_number,   -- Line item number on the Transfer Order

    -- Item Details
    partnum as part_number,         -- Part number (often redundant if partid is present)
    description as item_description,
    revisionnum as revision_number,
    typeid as item_type_id,         -- Type of item in the transfer
    statusid as item_status_id,     -- Status of this transfer order item
    uomid as uom_id,                -- Unit of Measure for this item

    -- Quantities
    qtytofulfill as quantity_to_fulfill,
    qtypicked as quantity_picked,
    qtyfulfilled as quantity_fulfilled,

    -- Costs
    totalcost as total_cost,        -- Total cost of this line item

    -- Timestamps
    datescheduledfulfillment as scheduled_fulfillment_date,
    datelastfulfillment as last_fulfillment_date,

    -- Other
    note as item_note,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
