with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'wo') }}
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
    id as work_order_id,            -- Renamed primary key
    num as work_order_number,       -- User-facing WO number
    moitemid as mo_item_id,         -- Foreign key to Manufacturing Order Item (if applicable)
    customerid as customer_id,      -- Customer associated with the WO (if applicable)

    -- WO Details
    statusid as status_id,          -- Status of the Work Order
    priorityid as priority_id,      -- Priority of the WO
    locationid as location_id,      -- Primary location for the WO
    locationgroupid as location_group_id, -- Location group for the WO
    userid as user_id,              -- User associated with the WO (creator/assignee)
    qbclassid as quickbooks_class_id, -- QuickBooks Class ID
    calcategoryid as calendar_category_id, -- Calendar category for scheduling

    -- Quantities
    qtytarget as quantity_target,   -- Target quantity to produce
    qtyordered as quantity_ordered, -- Quantity originally ordered (might differ from target)
    qtyscrapped as quantity_scrapped, -- Quantity scrapped during production

    -- Costs
    cost as total_cost,             -- Total cost of the Work Order

    -- Timestamps
    datecreated as created_at,
    datelastmodified as last_modified_at,
    datestarted as started_at,
    datefinished as finished_at,
    datescheduled as scheduled_completion_date,
    datescheduledtostart as scheduled_start_date,

    -- Other
    note as work_order_note,
    customfields as custom_fields,  -- Typically JSON or serialized string

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
