with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'receiptitem') }}
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
    id as receipt_item_id,          -- Renamed primary key for this receipt item record
    receiptid as receipt_id,        -- Foreign key to the RECEIPT table
    partid as part_id,              -- Foreign key to the PART table
    poitemid as po_item_id,         -- Foreign key to POITEM (if applicable)
    soitemid as so_item_id,         -- Foreign key to SOITEM (if applicable, e.g., RMA)
    xoitemid as xo_item_id,         -- Foreign key to XOITEM (if applicable)
    shipitemid as ship_item_id,     -- Foreign key to SHIPITEM (if related)
    tagid as tag_id,                -- Tag ID if item is tagged
    customerid as customer_id,      -- Customer ID (e.g., for RMAs)

    -- Item & Receipt Details
    typeid as receipt_item_type_id, -- Type of receipt item
    parttypeid as part_type_id,     -- Type of the part being received
    statusid as receipt_item_status_id, -- Status of this receipt item
    ordertypeid as order_type_id,    -- Type of order this item is associated with
    reason as reason_code,          -- Reason for receipt/return
    refno as reference_number,      -- General reference number
    deliverto as deliver_to_location, -- Specific location/person item was delivered to

    -- Quantity & UOM
    qty as quantity_received,
    uomid as uom_id,

    -- Cost & Tax
    billedtotalcost as billed_total_cost,
    mcbilledtotalcost as mc_billed_total_cost, -- Multi-currency billed total cost
    landedtotalcost as landed_total_cost,
    mclandedtotalcost as mc_landed_total_cost, -- Multi-currency landed total cost
    outsourcedcost as outsourced_cost,
    taxid as tax_id,
    taxrate as tax_rate,
    CAST(billvendorflag as BOOLEAN) as bill_vendor_flag, -- Flag to bill vendor (e.g., for returns)

    -- Shipping & Tracking
    carrierid as carrier_id,
    carrierserviceid as carrier_service_id,
    trackingnum as tracking_number,
    packagecount as package_count,

    -- Location & Responsibility
    locationid as location_id,      -- Location where the item was received
    responsibilityid as responsibility_id, -- Who is responsible (e.g., for discrepancies)

    -- Timestamps
    datereceived as received_at,
    datebilled as billed_at,
    datereconciled as reconciled_at,
    datelastmodified as last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
