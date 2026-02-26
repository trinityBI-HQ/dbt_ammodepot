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
        num,
        sku,
        upc,
        partid, -- May be related to 'id' or a component part identifier

        -- Product Description & Details
        description,
        details,
        url,
        alertnote,

        -- Dimensions & Weight
        len,
        width,
        height,
        weight,
        uomid, -- Unit of Measure ID for primary measure
        sizeuomid, -- Unit of Measure ID for dimensions (len, width, height)
        weightuomid, -- Unit of Measure ID for weight

        -- Pricing & Tax
        price,
        usepriceflag, -- Flag indicating if this price should be used
        taxid,
        taxableflag,

        -- Flags & Status
        activeflag,
        kitflag,
        kitgroupedflag, -- Specific type of kit grouping?
        showsocomboflag, -- Flag for display on SO combos?
        sellableinotheruoms,

        -- Timestamps
        datecreated,
        datelastmodified,

        -- Relationships & Classifications
        displaytypeid,
        defaultsoitemtype,
        defaultcartontypeid,
        cartoncount,
        qbclassid, -- QuickBooks Class ID

        -- Accounting Info (Select based on need)
        accountingid,
        accountinghash,
        incomeaccountid,

        -- Custom Fields
        customfields, -- Typically JSON or serialized string

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'product') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Core Identifiers
    id as product_id,           -- Renamed primary key
    num as product_number,
    sku as product_sku,
    upc as product_upc,
    partid as part_id,          -- Keep as part_id, assuming it refers to a component or internal part system

    -- Product Description & Details
    description as product_description,
    details as product_details,
    url as product_url,
    alertnote as alert_note,

    -- Dimensions & Weight
    len as length,
    width,
    height,
    weight,
    uomid as uom_id,
    sizeuomid as size_uom_id,
    weightuomid as weight_uom_id,

    -- Pricing & Tax
    price as unit_price,
    CAST(usepriceflag as BOOLEAN) as use_list_price,
    taxid as tax_id,
    CAST(taxableflag as BOOLEAN) as is_taxable,

    -- Flags & Status
    CAST(activeflag as BOOLEAN) as is_active,
    CAST(kitflag as BOOLEAN) as is_kit,
    CAST(kitgroupedflag as BOOLEAN) as is_kit_grouped,
    CAST(showsocomboflag as BOOLEAN) as show_on_so_combo,
    CAST(sellableinotheruoms as BOOLEAN) as is_sellable_in_other_uoms,

    -- Timestamps
    datecreated as created_at,
    datelastmodified as last_modified_at,

    -- Relationships & Classifications
    displaytypeid as display_type_id,
    defaultsoitemtype as default_so_item_type_id,
    defaultcartontypeid as default_carton_type_id,
    cartoncount as carton_count,
    qbclassid as quickbooks_class_id,

    -- Accounting Info
    accountingid as accounting_id,
    accountinghash as accounting_hash,
    incomeaccountid as income_account_id,

    -- Custom Fields
    customfields as custom_fields

from
    source_data
