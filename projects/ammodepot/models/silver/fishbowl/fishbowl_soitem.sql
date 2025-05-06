{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Core Identifiers
        id,
        soid,             -- Foreign Key to the Sales Order (SO) table
        productid,        -- Foreign Key to the Product table
        solineitem,       -- Line item number within the Sales Order

        -- Item Details
        productnum,       -- Product Number (often redundant if productid is present, but useful)
        description,
        customerpartnum,  -- Customer's specific part number for this item
        revlevel,         -- Revision Level
        note,

        -- Quantity Information
        qtyordered,
        qtyfulfilled,
        qtypicked,
        qtytofulfill,

        -- Pricing & Financials
        unitprice,
        totalprice,       -- Typically quantity * unit_price (before adjustments/taxes)
        mctotalprice,     -- Multi-currency total price
        totalcost,        -- Cost of goods for this line item
        markupcost,       -- Cost used for markup calculation (could differ from totalcost)
        taxid,            -- Tax code/rule applied
        taxrate,          -- Actual tax rate applied (percentage)
        taxableflag,      -- Boolean flag if the item is taxable
        adjustamount,     -- Manual adjustment amount
        adjustpercentage, -- Manual adjustment percentage
        itemadjustid,     -- Link to a specific adjustment record?

        -- Relationships & Classifications
        typeid,           -- Item type ID (e.g., sale, credit, drop ship)
        statusid,         -- Line item status ID
        uomid,            -- Unit of Measure ID
        qbclassid,        -- QuickBooks Class ID

        -- Flags
        showitemflag,     -- Flag to control visibility?

        -- Timestamps
        datelastfulfillment,
        datescheduledfulfillment,
        datelastmodified, -- Last modified timestamp for the item itself

        -- Other Related Info
        exchangesolineitem, -- Related SO line item for exchanges?
        customfields,     -- Custom data field

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'soitem') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    id AS so_item_id,           -- Renamed primary key
    soid AS sales_order_id,     -- Renamed foreign key to SO
    productid AS product_id,    -- Renamed foreign key to Product
    solineitem AS line_item_number,

    -- Item Details
    productnum AS product_number,
    description AS product_description,
    customerpartnum AS customer_part_number,
    revlevel AS revision_level,
    note,

    -- Quantity Information
    qtyordered AS quantity_ordered,
    qtyfulfilled AS quantity_fulfilled,
    qtypicked AS quantity_picked,
    qtytofulfill AS quantity_to_fulfill,

    -- Pricing & Financials
    unitprice AS unit_price,
    totalprice AS total_price,
    mctotalprice AS mc_total_price,
    totalcost AS total_cost,
    markupcost AS markup_cost,
    taxid AS tax_id,
    taxrate AS tax_rate,
    CAST(taxableflag AS BOOLEAN) AS is_taxable,
    adjustamount AS adjustment_amount,
    adjustpercentage AS adjustment_percentage,
    itemadjustid AS item_adjustment_id,

    -- Relationships & Classifications
    typeid AS item_type_id,
    statusid AS status_id,
    uomid AS uom_id,
    qbclassid AS quickbooks_class_id,

    -- Flags
    CAST(showitemflag AS BOOLEAN) AS show_item,

    -- Timestamps
    datelastfulfillment AS last_fulfillment_date,
    datescheduledfulfillment AS scheduled_fulfillment_date,
    datelastmodified AS last_modified_at,

    -- Other Related Info
    exchangesolineitem AS exchange_so_line_item,
    customfields AS custom_fields

FROM
    source_data