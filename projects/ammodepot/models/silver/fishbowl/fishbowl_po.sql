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
        num,
        url,
        note,
        buyer,
        email,
        phone,
        typeid,
        buyerid,
        remitzip,
        statusid,
        totaltax,
        username,
        vendorid,
        vendorso,
        carrierid,
        deliverto,
        qbclassid,
        remitcity,
        shiptozip,
        taxrateid,
        currencyid,
        customerso,
        dateissued,
        fobpointid,
        shiptocity,
        shiptoname,
        datecreated,
        remittoname,
        revisionnum,
        shiptermsid,
        taxratename,
        currencyrate,
        customfields,
        daterevision,
        remitaddress,
        remitstateid,
        datecompleted,
        dateconfirmed,
        datefirstship,
        shiptoaddress,
        shiptostateid,
        vendorcontact,
        issuedbyuserid,
        paymenttermsid,
        remitcountryid,
        locationgroupid,
        shiptocountryid,
        carrierserviceid,
        datelastmodified,
        totalincludestax,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'po') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    id AS purchase_order_id,        -- Renamed primary key
    num AS purchase_order_number,
    vendorid AS vendor_id,
    typeid AS po_type_id,
    statusid AS po_status_id,

    -- Dates & Timestamps
    datecreated AS created_at,
    dateissued AS issued_at,
    datelastmodified AS last_modified_at,
    dateconfirmed AS confirmed_at,
    datecompleted AS completed_at,
    datefirstship AS first_ship_date,
    daterevision AS revision_date,

    -- Vendor & Contact Info
    vendorso AS vendor_sales_order_number,
    vendorcontact AS vendor_contact_name,
    email AS vendor_email, -- Assuming this is vendor email
    phone AS vendor_phone, -- Assuming this is vendor phone

    -- Buyer & User Info
    buyer AS buyer_name,
    buyerid AS buyer_id, -- Potentially user ID of buyer
    username AS user_name, -- User who created/modified
    issuedbyuserid AS issued_by_user_id,

    -- Financials
    totaltax AS total_tax,
    currencyid AS currency_id,
    currencyrate AS currency_rate,
    taxrateid AS tax_rate_id,
    taxratename AS tax_rate_name,
    CAST(totalincludestax AS BOOLEAN) AS is_total_including_tax,
    paymenttermsid AS payment_terms_id,

    -- Shipping Address
    shiptoname AS ship_to_name,
    shiptoaddress AS ship_to_address,
    shiptocity AS ship_to_city,
    shiptozip AS ship_to_zip,
    shiptostateid AS ship_to_state_id,
    shiptocountryid AS ship_to_country_id,
    deliverto AS deliver_to_location_name,

    -- Remit To Address (Vendor's payment address)
    remittoname AS remit_to_name,
    remitaddress AS remit_to_address,
    remitcity AS remit_to_city,
    remitzip AS remit_to_zip,
    remitstateid AS remit_to_state_id,
    remitcountryid AS remit_to_country_id,

    -- Shipping & Carrier Details
    carrierid AS carrier_id,
    carrierserviceid AS carrier_service_id,
    shiptermsid AS ship_terms_id,
    fobpointid AS fob_point_id,

    -- Order Details & Flags
    note AS po_note,
    url AS po_url,
    revisionnum AS revision_number,
    customerso AS customer_so_number, -- If this PO is to fulfill a customer SO
    locationgroupid AS location_group_id,
    qbclassid AS quickbooks_class_id,
    customfields AS custom_fields,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data