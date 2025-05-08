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
    FROM
        {{ source('fishbowl', 'poitem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS po_item_id,               -- Renamed primary key for this PO item record
    poid AS purchase_order_id,      -- Foreign key to the PO table
    partid AS part_id,              -- Foreign key to the PART table
    polineitem AS po_line_item_number,

    -- Item Details
    partnum AS part_number,
    description AS item_description,
    vendorpartnum AS vendor_part_number,
    revlevel AS revision_level,
    customerid AS customer_id,      -- Customer ID (if for a specific customer order)

    -- Outsourced Part Details (if applicable)
    outsourcedpartid AS outsourced_part_id,
    outsourcedpartnumber AS outsourced_part_number,
    outsourcedpartdescription AS outsourced_part_description,

    -- Type & Status
    typeid AS po_item_type_id,
    statusid AS po_item_status_id,

    -- Quantity & UOM
    qtytofulfill AS quantity_ordered, -- Renamed to match SOItem convention
    qtyfulfilled AS quantity_fulfilled,
    qtypicked AS quantity_picked,
    uomid AS uom_id,

    -- Cost & Tax
    unitcost AS unit_cost,
    totalcost AS total_cost,
    mctotalcost AS mc_total_cost,    -- Multi-currency total cost
    taxid AS tax_id,
    taxrate AS tax_rate,
    CAST(tbdcostflag AS BOOLEAN) AS is_cost_tbd, -- To Be Determined cost flag
    CAST(repairflag AS BOOLEAN) AS is_repair_item, -- Flag for repair items

    -- Classification & Customization
    qbclassid AS quickbooks_class_id,
    customfields AS custom_fields,  -- Typically JSON or serialized string
    note AS item_note,

    -- Timestamps
    datescheduledfulfillment AS scheduled_fulfillment_date,
    datelastfulfillment AS last_fulfillment_date,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data
