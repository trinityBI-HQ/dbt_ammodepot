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

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'product') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    id AS product_id,           -- Renamed primary key
    num AS product_number,
    sku AS product_sku,
    upc AS product_upc,
    partid AS part_id,          -- Keep as part_id, assuming it refers to a component or internal part system

    -- Product Description & Details
    description AS product_description,
    details AS product_details,
    url AS product_url,
    alertnote AS alert_note,

    -- Dimensions & Weight
    len AS length,
    width,
    height,
    weight,
    uomid AS uom_id,
    sizeuomid AS size_uom_id,
    weightuomid AS weight_uom_id,

    -- Pricing & Tax
    price AS unit_price,
    CAST(usepriceflag AS BOOLEAN) AS use_list_price,
    taxid AS tax_id,
    CAST(taxableflag AS BOOLEAN) AS is_taxable,

    -- Flags & Status
    CAST(activeflag AS BOOLEAN) AS is_active,
    CAST(kitflag AS BOOLEAN) AS is_kit,
    CAST(kitgroupedflag AS BOOLEAN) AS is_kit_grouped,
    CAST(showsocomboflag AS BOOLEAN) AS show_on_so_combo,
    CAST(sellableinotheruoms AS BOOLEAN) AS is_sellable_in_other_uoms,

    -- Timestamps
    datecreated AS created_at,
    datelastmodified AS last_modified_at,

    -- Relationships & Classifications
    displaytypeid AS display_type_id,
    defaultsoitemtype AS default_so_item_type_id,
    defaultcartontypeid AS default_carton_type_id,
    cartoncount AS carton_count,
    qbclassid AS quickbooks_class_id,

    -- Accounting Info
    accountingid AS accounting_id,
    accountinghash AS accounting_hash,
    incomeaccountid AS income_account_id,

    -- Custom Fields
    customfields AS custom_fields

FROM
    source_data