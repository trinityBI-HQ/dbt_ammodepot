with source_data as (

    select
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

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SO
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'so') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Core Identifiers
    id as sales_order_id, -- Renamed primary key
    num as sales_order_number,
    customerid as customer_id,
    typeid as order_type_id,
    statusid as status_id,

    -- Dates & Timestamps
    datecreated as created_at,
    dateissued as issued_at,
    datelastmodified as last_modified_at,
    datecompleted as completed_at,
    dateexpired as expires_at,
    datefirstship as first_ship_date,
    daterevision as revision_date,

    -- Financials
    subtotal,
    totaltax as total_tax,
    totalprice as total_price,
    cost as total_cost,
    estimatedtax as estimated_tax,
    mctotaltax as mc_total_tax,
    currencyid as currency_id,
    currencyrate as currency_rate,
    CAST(totalincludestax as BOOLEAN) as is_total_including_tax,

    -- Customer & Contact Info
    customerpo as customer_po_number,
    customercontact as customer_contact_name,
    email as customer_email,
    phone as customer_phone,

    -- Billing Address
    billtoname as bill_to_name,
    billtoaddress as bill_to_address,
    billtocity as bill_to_city,
    billtozip as bill_to_zip,
    billtostateid as bill_to_state_id,
    billtocountryid as bill_to_country_id,

    -- Shipping Address
    shiptoname as ship_to_name,
    shiptoaddress as ship_to_address,
    shiptocity as ship_to_city,
    shiptozip as ship_to_zip,
    shiptostateid as ship_to_state_id,
    shiptocountryid as ship_to_country_id,
    CAST(shiptoresidential as BOOLEAN) as is_ship_to_residential,

    -- Shipping & Carrier Details
    carrierid as carrier_id,
    carrierserviceid as carrier_service_id,
    shiptermsid as ship_terms_id,
    fobpointid as fob_point_id,

    -- Sales & Internal Info
    salesman as salesman_name,
    salesmanid as salesman_id,
    salesmaninitials as salesman_initials,
    priorityid as priority_id,
    locationgroupid as location_group_id,
    username as user_name,
    createdbyuserid as created_by_user_id,
    registerid as register_id,
    qbclassid as quickbooks_class_id,
    vendorpo as vendor_po_number,

    -- Order Details & Flags
    note,
    url,
    revisionnum as revision_number,
    paymenttermsid as payment_terms_id,
    taxrateid as tax_rate_id,
    taxratename as tax_rate_name,
    taxrate as tax_rate,
    CAST(tobeemailed as BOOLEAN) as to_be_emailed,
    CAST(tobeprinted as BOOLEAN) as to_be_printed,
    paymentlink as payment_link,
    customfields as custom_fields

from
    source_data
