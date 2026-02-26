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
    from
        {{ source('fishbowl', 'woitem') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as wo_item_id,               -- Renamed primary key for this Work Order item
    woid as work_order_id,          -- Foreign key to the WO table
    partid as part_id,              -- Foreign key to the PART table (component or finished good)
    moitemid as mo_item_id,         -- Foreign key to Manufacturing Order Item (if applicable)

    -- Item Details
    typeid as item_type_id,         -- Type of item (e.g., component, finished good, scrap)
    description as item_description,
    uomid as uom_id,                -- Unit of Measure for this item
    sortid as sort_order,           -- Sort order for display

    -- Quantities
    qtytarget as quantity_target,   -- Target quantity for this item
    qtyused as quantity_used,       -- Quantity actually used/produced
    qtyscrapped as quantity_scrapped, -- Quantity of this item scrapped

    -- Costs
    cost as actual_cost,            -- Actual cost associated with this item
    standardcost as standard_cost,  -- Standard cost for this item

    -- Flags
    CAST(onetimeitem as BOOLEAN) as is_one_time_item, -- Flag indicating if this is a one-time item

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
