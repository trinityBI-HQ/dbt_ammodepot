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
        woid,
        uomid,
        partid,
        sortid,
        typeid,
        qtyused,
        moitemid,
        qtytarget,
        description,
        onetimeitem,
        qtyscrapped,
        standardcost,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'woitem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS wo_item_id,               -- Renamed primary key for this Work Order item
    woid AS work_order_id,          -- Foreign key to the WO table
    partid AS part_id,              -- Foreign key to the PART table (component or finished good)
    moitemid AS mo_item_id,         -- Foreign key to Manufacturing Order Item (if applicable)

    -- Item Details
    typeid AS item_type_id,         -- Type of item (e.g., component, finished good, scrap)
    description AS item_description,
    uomid AS uom_id,                -- Unit of Measure for this item
    sortid AS sort_order,           -- Sort order for display

    -- Quantities
    qtytarget AS quantity_target,   -- Target quantity for this item
    qtyused AS quantity_used,       -- Quantity actually used/produced
    qtyscrapped AS quantity_scrapped, -- Quantity of this item scrapped

    -- Costs
    cost AS actual_cost,            -- Actual cost associated with this item
    standardcost AS standard_cost,  -- Standard cost for this item

    -- Flags
    CAST(onetimeitem AS BOOLEAN) AS is_one_time_item, -- Flag indicating if this is a one-time item

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data