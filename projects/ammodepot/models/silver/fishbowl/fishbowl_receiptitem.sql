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
        qty,
        refno,
        tagid,
        taxid,
        uomid,
        partid,
        reason,
        typeid,
        taxrate,
        poitemid,
        soitemid,
        statusid,
        xoitemid,
        carrierid,
        deliverto,
        receiptid,
        customerid,
        datebilled,
        locationid,
        parttypeid,
        shipitemid,
        ordertypeid,
        trackingnum,
        datereceived,
        packagecount,
        billvendorflag,
        datereconciled,
        outsourcedcost,
        billedtotalcost,
        landedtotalcost,
        carrierserviceid,
        datelastmodified,
        responsibilityid,
        mcbilledtotalcost,
        mclandedtotalcost,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'receiptitem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS receipt_item_id,          -- Renamed primary key for this receipt item record
    receiptid AS receipt_id,        -- Foreign key to the RECEIPT table
    partid AS part_id,              -- Foreign key to the PART table
    poitemid AS po_item_id,         -- Foreign key to POITEM (if applicable)
    soitemid AS so_item_id,         -- Foreign key to SOITEM (if applicable, e.g., RMA)
    xoitemid AS xo_item_id,         -- Foreign key to XOITEM (if applicable)
    shipitemid AS ship_item_id,     -- Foreign key to SHIPITEM (if related)
    tagid AS tag_id,                -- Tag ID if item is tagged
    customerid AS customer_id,      -- Customer ID (e.g., for RMAs)

    -- Item & Receipt Details
    typeid AS receipt_item_type_id, -- Type of receipt item
    parttypeid AS part_type_id,     -- Type of the part being received
    statusid AS receipt_item_status_id, -- Status of this receipt item
    ordertypeid AS order_type_id,    -- Type of order this item is associated with
    reason AS reason_code,          -- Reason for receipt/return
    refno AS reference_number,      -- General reference number
    deliverto AS deliver_to_location, -- Specific location/person item was delivered to

    -- Quantity & UOM
    qty AS quantity_received,
    uomid AS uom_id,

    -- Cost & Tax
    billedtotalcost AS billed_total_cost,
    mcbilledtotalcost AS mc_billed_total_cost, -- Multi-currency billed total cost
    landedtotalcost AS landed_total_cost,
    mclandedtotalcost AS mc_landed_total_cost, -- Multi-currency landed total cost
    outsourcedcost AS outsourced_cost,
    taxid AS tax_id,
    taxrate AS tax_rate,
    CAST(billvendorflag AS BOOLEAN) AS bill_vendor_flag, -- Flag to bill vendor (e.g., for returns)

    -- Shipping & Tracking
    carrierid AS carrier_id,
    carrierserviceid AS carrier_service_id,
    trackingnum AS tracking_number,
    packagecount AS package_count,

    -- Location & Responsibility
    locationid AS location_id,      -- Location where the item was received
    responsibilityid AS responsibility_id, -- Who is responsible (e.g., for discrepancies)

    -- Timestamps
    datereceived AS received_at,
    datebilled AS billed_at,
    datereconciled AS reconciled_at,
    datelastmodified AS last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data