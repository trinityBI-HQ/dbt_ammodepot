with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'po') }}
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
    -- Core Identifiers
    id as purchase_order_id,        -- Renamed primary key
    num as purchase_order_number,
    vendorid as vendor_id,
    typeid as po_type_id,
    statusid as po_status_id,

    -- Dates & Timestamps
    datecreated as created_at,
    dateissued as issued_at,
    datelastmodified as last_modified_at,
    dateconfirmed as confirmed_at,
    datecompleted as completed_at,
    datefirstship as first_ship_date,
    daterevision as revision_date,

    -- Vendor & Contact Info
    vendorso as vendor_sales_order_number,
    vendorcontact as vendor_contact_name,
    email as vendor_email, -- Assuming this is vendor email
    phone as vendor_phone, -- Assuming this is vendor phone

    -- Buyer & User Info
    buyer as buyer_name,
    buyerid as buyer_id, -- Potentially user ID of buyer
    username as user_name, -- User who created/modified
    issuedbyuserid as issued_by_user_id,

    -- Financials
    totaltax as total_tax,
    currencyid as currency_id,
    currencyrate as currency_rate,
    taxrateid as tax_rate_id,
    taxratename as tax_rate_name,
    CAST(totalincludestax as BOOLEAN) as is_total_including_tax,
    paymenttermsid as payment_terms_id,

    -- Shipping Address
    shiptoname as ship_to_name,
    shiptoaddress as ship_to_address,
    shiptocity as ship_to_city,
    shiptozip as ship_to_zip,
    shiptostateid as ship_to_state_id,
    shiptocountryid as ship_to_country_id,
    deliverto as deliver_to_location_name,

    -- Remit To Address (Vendor's payment address)
    remittoname as remit_to_name,
    remitaddress as remit_to_address,
    remitcity as remit_to_city,
    remitzip as remit_to_zip,
    remitstateid as remit_to_state_id,
    remitcountryid as remit_to_country_id,

    -- Shipping & Carrier Details
    carrierid as carrier_id,
    carrierserviceid as carrier_service_id,
    shiptermsid as ship_terms_id,
    fobpointid as fob_point_id,

    -- Order Details & Flags
    note as po_note,
    url as po_url,
    revisionnum as revision_number,
    customerso as customer_so_number, -- If this PO is to fulfill a customer SO
    locationgroupid as location_group_id,
    qbclassid as quickbooks_class_id,
    customfields as custom_fields,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
