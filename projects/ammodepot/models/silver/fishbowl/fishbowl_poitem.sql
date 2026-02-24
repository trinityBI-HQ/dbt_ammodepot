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
        note,
        poid,
        taxid,
        uomid,
        partid,
        typeid,
        partnum,
        taxrate,
        revlevel,
        statusid,
        unitcost,
        qbclassid,
        qtypicked,
        totalcost,
        customerid,
        polineitem,
        repairflag,
        description,
        mctotalcost,
        tbdcostflag,
        customfields,
        qtyfulfilled,
        qtytofulfill,
        vendorpartnum,
        outsourcedpartid,
        datelastfulfillment,
        outsourcedpartnumber,
        datescheduledfulfillment,
        outsourcedpartdescription,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'poitem') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as po_item_id,               -- Renamed primary key for this PO item record
    poid as purchase_order_id,      -- Foreign key to the PO table
    partid as part_id,              -- Foreign key to the PART table
    polineitem as po_line_item_number,

    -- Item Details
    partnum as part_number,
    description as item_description,
    vendorpartnum as vendor_part_number,
    revlevel as revision_level,
    customerid as customer_id,      -- Customer ID (if for a specific customer order)

    -- Outsourced Part Details (if applicable)
    outsourcedpartid as outsourced_part_id,
    outsourcedpartnumber as outsourced_part_number,
    outsourcedpartdescription as outsourced_part_description,

    -- Type & Status
    typeid as po_item_type_id,
    statusid as po_item_status_id,

    -- Quantity & UOM
    qtytofulfill as quantity_ordered, -- Renamed to match SOItem convention
    qtyfulfilled as quantity_fulfilled,
    qtypicked as quantity_picked,
    uomid as uom_id,

    -- Cost & Tax
    unitcost as unit_cost,
    totalcost as total_cost,
    mctotalcost as mc_total_cost,    -- Multi-currency total cost
    taxid as tax_id,
    taxrate as tax_rate,
    CAST(tbdcostflag as BOOLEAN) as is_cost_tbd, -- To Be Determined cost flag
    CAST(repairflag as BOOLEAN) as is_repair_item, -- Flag for repair items

    -- Classification & Customization
    qbclassid as quickbooks_class_id,
    customfields as custom_fields,  -- Typically JSON or serialized string
    note as item_note,

    -- Timestamps
    datescheduledfulfillment as scheduled_fulfillment_date,
    datelastfulfillment as last_fulfillment_date,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
