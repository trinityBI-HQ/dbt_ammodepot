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
        customerid,
        typeid,
        statusid,

        -- Dates & Timestamps
        datecreated,
        dateissued,
        datelastmodified,
        datecompleted,
        dateexpired,
        datefirstship,
        daterevision,
        -- datecalend, -- Consider if needed
        -- datecalstart, -- Consider if needed

        -- Financials
        subtotal,
        totaltax,
        totalprice, -- Assuming this is the grand total
        cost, -- Order cost (if applicable)
        estimatedtax,
        mctotaltax, -- Multi-currency total tax
        currencyid,
        currencyrate,
        totalincludestax, -- Flag

        -- Customer & Contact Info
        customerpo,
        customercontact,
        email,
        phone,

        -- Billing Address
        billtoname,
        billtoaddress,
        billtocity,
        billtozip,
        billtostateid,
        billtocountryid,

        -- Shipping Address
        shiptoname,
        shiptoaddress,
        shiptocity,
        shiptozip,
        shiptostateid,
        shiptocountryid,
        shiptoresidential, -- Flag

        -- Shipping & Carrier Details
        carrierid,
        carrierserviceid,
        shiptermsid,
        fobpointid,

        -- Sales & Internal Info
        salesman, -- Name
        salesmanid, -- ID
        salesmaninitials,
        priorityid,
        locationgroupid,
        username, -- User associated (check context vs createdbyuserid)
        createdbyuserid,
        registerid, -- POS Register?
        qbclassid, -- QuickBooks Class ID?
        vendorpo, -- Related Vendor PO?

        -- Order Details & Flags
        note,
        url,
        revisionnum,
        paymenttermsid,
        taxrateid,
        taxratename,
        taxrate, -- Actual rate value?
        tobeemailed, -- Flag
        tobeprinted, -- Flag
        paymentlink,
        customfields, -- JSON/Text custom data

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT
        -- CALCATEGORYID, DATECALEND, DATECALSTART unless specifically required


    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SO
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'so') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    id AS sales_order_id, -- Renamed primary key
    num AS sales_order_number,
    customerid AS customer_id,
    typeid AS order_type_id,
    statusid AS status_id,

    -- Dates & Timestamps
    datecreated AS created_at,
    dateissued AS issued_at,
    datelastmodified AS last_modified_at,
    datecompleted AS completed_at,
    dateexpired AS expires_at,
    datefirstship AS first_ship_date,
    daterevision AS revision_date,

    -- Financials
    subtotal,
    totaltax AS total_tax,
    totalprice AS total_price,
    cost AS total_cost,
    estimatedtax AS estimated_tax,
    mctotaltax AS mc_total_tax,
    currencyid AS currency_id,
    currencyrate AS currency_rate,
    CAST(totalincludestax AS BOOLEAN) AS is_total_including_tax,

    -- Customer & Contact Info
    customerpo AS customer_po_number,
    customercontact AS customer_contact_name,
    email AS customer_email,
    phone AS customer_phone,

    -- Billing Address
    billtoname AS bill_to_name,
    billtoaddress AS bill_to_address,
    billtocity AS bill_to_city,
    billtozip AS bill_to_zip,
    billtostateid AS bill_to_state_id,
    billtocountryid AS bill_to_country_id,

    -- Shipping Address
    shiptoname AS ship_to_name,
    shiptoaddress AS ship_to_address,
    shiptocity AS ship_to_city,
    shiptozip AS ship_to_zip,
    shiptostateid AS ship_to_state_id,
    shiptocountryid AS ship_to_country_id,
    CAST(shiptoresidential AS BOOLEAN) AS is_ship_to_residential,

    -- Shipping & Carrier Details
    carrierid AS carrier_id,
    carrierserviceid AS carrier_service_id,
    shiptermsid AS ship_terms_id,
    fobpointid AS fob_point_id,

    -- Sales & Internal Info
    salesman AS salesman_name,
    salesmanid AS salesman_id,
    salesmaninitials AS salesman_initials,
    priorityid AS priority_id,
    locationgroupid AS location_group_id,
    username AS user_name,
    createdbyuserid AS created_by_user_id,
    registerid AS register_id,
    qbclassid AS quickbooks_class_id,
    vendorpo AS vendor_po_number,

    -- Order Details & Flags
    note,
    url,
    revisionnum AS revision_number,
    paymenttermsid AS payment_terms_id,
    taxrateid AS tax_rate_id,
    taxratename AS tax_rate_name,
    taxrate AS tax_rate,
    CAST(tobeemailed AS BOOLEAN) AS to_be_emailed,
    CAST(tobeprinted AS BOOLEAN) AS to_be_printed,
    paymentlink AS payment_link,
    customfields AS custom_fields

FROM
    source_data