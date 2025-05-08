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
        cost,
        note,
        userid,
        moitemid,
        statusid,
        qbclassid,
        qtytarget,
        customerid,
        locationid,
        priorityid,
        qtyordered,
        datecreated,
        datestarted,
        qtyscrapped,
        customfields,
        datefinished,
        calcategoryid,
        datescheduled,
        locationgroupid,
        datelastmodified,
        datescheduledtostart,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'wo') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS work_order_id,            -- Renamed primary key
    num AS work_order_number,       -- User-facing WO number
    moitemid AS mo_item_id,         -- Foreign key to Manufacturing Order Item (if applicable)
    customerid AS customer_id,      -- Customer associated with the WO (if applicable)

    -- WO Details
    statusid AS status_id,          -- Status of the Work Order
    priorityid AS priority_id,      -- Priority of the WO
    locationid AS location_id,      -- Primary location for the WO
    locationgroupid AS location_group_id, -- Location group for the WO
    userid AS user_id,              -- User associated with the WO (creator/assignee)
    qbclassid AS quickbooks_class_id, -- QuickBooks Class ID
    calcategoryid AS calendar_category_id, -- Calendar category for scheduling

    -- Quantities
    qtytarget AS quantity_target,   -- Target quantity to produce
    qtyordered AS quantity_ordered, -- Quantity originally ordered (might differ from target)
    qtyscrapped AS quantity_scrapped, -- Quantity scrapped during production

    -- Costs
    cost AS total_cost,             -- Total cost of the Work Order

    -- Timestamps
    datecreated AS created_at,
    datelastmodified AS last_modified_at,
    datestarted AS started_at,
    datefinished AS finished_at,
    datescheduled AS scheduled_completion_date,
    datescheduledtostart AS scheduled_start_date,

    -- Other
    note AS work_order_note,
    customfields AS custom_fields,  -- Typically JSON or serialized string

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data