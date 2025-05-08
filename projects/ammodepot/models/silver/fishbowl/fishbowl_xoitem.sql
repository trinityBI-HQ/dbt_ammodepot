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
    FROM
        {{ source('fishbowl', 'xoitem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS xo_item_id,               -- Renamed primary key for this Transfer Order item
    xoid AS transfer_order_id,      -- Foreign key to the XO table
    partid AS part_id,              -- Foreign key to the PART table
    lineitem AS line_item_number,   -- Line item number on the Transfer Order

    -- Item Details
    partnum AS part_number,         -- Part number (often redundant if partid is present)
    description AS item_description,
    revisionnum AS revision_number,
    typeid AS item_type_id,         -- Type of item in the transfer
    statusid AS item_status_id,     -- Status of this transfer order item
    uomid AS uom_id,                -- Unit of Measure for this item

    -- Quantities
    qtytofulfill AS quantity_to_fulfill,
    qtypicked AS quantity_picked,
    qtyfulfilled AS quantity_fulfilled,

    -- Costs
    totalcost AS total_cost,        -- Total cost of this line item

    -- Timestamps
    datescheduledfulfillment AS scheduled_fulfillment_date,
    datelastfulfillment AS last_fulfillment_date,

    -- Other
    note AS item_note,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data