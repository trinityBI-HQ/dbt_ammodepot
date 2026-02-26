{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (

    select
        -- Core Identifiers
        id,
        soid,             -- Foreign Key to the Sales Order (SO) view
        productid,        -- Foreign Key to the Product view
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

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'soitem') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Core Identifiers
    id as so_item_id,           -- Renamed primary key
    soid as sales_order_id,     -- Renamed foreign key to SO
    productid as product_id,    -- Renamed foreign key to Product
    solineitem as line_item_number,

    -- Item Details
    productnum as product_number,
    description as product_description,
    customerpartnum as customer_part_number,
    revlevel as revision_level,
    note,

    -- Quantity Information
    qtyordered as quantity_ordered,
    qtyfulfilled as quantity_fulfilled,
    qtypicked as quantity_picked,
    qtytofulfill as quantity_to_fulfill,

    -- Pricing & Financials
    unitprice as unit_price,
    totalprice as total_price,
    mctotalprice as mc_total_price,
    totalcost as total_cost,
    markupcost as markup_cost,
    taxid as tax_id,
    taxrate as tax_rate,
    CAST(taxableflag as BOOLEAN) as is_taxable,
    adjustamount as adjustment_amount,
    adjustpercentage as adjustment_percentage,
    itemadjustid as item_adjustment_id,

    -- Relationships & Classifications
    typeid as item_type_id,
    statusid as status_id,
    uomid as uom_id,
    qbclassid as quickbooks_class_id,

    -- Flags
    CAST(showitemflag as BOOLEAN) as show_item,

    -- Timestamps
    datelastfulfillment as last_fulfillment_date,
    datescheduledfulfillment as scheduled_fulfillment_date,
    datelastmodified as last_modified_at,

    -- Other Related Info
    exchangesolineitem as exchange_so_line_item,
    customfields as custom_fields

from
    source_data
