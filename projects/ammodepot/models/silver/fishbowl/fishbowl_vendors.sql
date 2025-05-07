{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        id,
        name,
        note,
        url,
        leadtime,
        statusid,
        accountid,
        sysuserid,
        taxrateid,
        accountnum,
        activeflag,
        currencyid,
        creditlimit,
        dateentered,
        accountingid,
        currencyrate,
        customfields,
        accountinghash,
        minorderamount,
        lastchangeduser,
        datelastmodified,
        defaultcarrierid,
        defaultshiptermsid,
        defaultpaymenttermsid,
        defaultcarrierserviceid
    FROM 
        {{ source('fishbowl', 'vendor') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS vendor_id,
    name AS vendor_name,
    note AS vendor_note,
    url AS vendor_url,
    leadtime AS lead_time_days,
    statusid AS status_id,
    accountid AS account_id,
    sysuserid AS sysuser_id,
    taxrateid AS tax_rate_id,
    accountnum AS account_number,
    activeflag AS is_active,
    currencyid AS currency_id,
    creditlimit AS credit_limit,
    dateentered AS date_entered,
    accountingid AS accounting_id,
    currencyrate AS currency_rate,
    customfields AS custom_fields,
    accountinghash AS accounting_hash,
    minorderamount AS minimum_order_amount,
    lastchangeduser AS last_changed_user,
    datelastmodified AS date_last_modified,
    defaultcarrierid AS default_carrier_id,
    defaultshiptermsid AS default_ship_terms_id,
    defaultpaymenttermsid AS default_payment_terms_id,
    defaultcarrierserviceid AS default_carrier_service_id
FROM 
    source_data