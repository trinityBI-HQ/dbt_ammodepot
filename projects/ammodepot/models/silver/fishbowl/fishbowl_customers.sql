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
        number,
        statusid,
        accountid,
        sysuserid,
        taxexempt,
        taxrateid,
        activeflag,
        currencyid,
        creditlimit,
        datecreated,
        tobeemailed,
        tobeprinted,
        accountingid,
        currencyrate,
        customfields,
        accountinghash,
        taxexemptnumber,
        carrierserviceid,
        datelastmodified,
        defaultcarrierid,
        issuablestatusid,
        defaultpriorityid,
        defaultsalesmanid,
        defaultshiptermsid,
        defaultpaymenttermsid,
        note,
        url,
        lastchangeduser
    FROM 
        {{ source('fishbowl', 'customer') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS customer_id,
    name AS customer_name,
    number AS customer_number,
    statusid AS status_id,
    accountid AS account_id,
    sysuserid AS sysuser_id,
    taxexempt AS is_tax_exempt,
    taxrateid AS tax_rate_id,
    activeflag AS is_active,
    currencyid AS currency_id,
    creditlimit AS credit_limit,
    datecreated AS date_created,
    tobeemailed AS to_be_emailed,
    tobeprinted AS to_be_printed,
    accountingid AS accounting_id,
    currencyrate AS currency_rate,
    customfields AS custom_fields,
    accountinghash AS accounting_hash,
    taxexemptnumber AS tax_exempt_number,
    carrierserviceid AS carrier_service_id,
    datelastmodified AS date_last_modified,
    defaultcarrierid AS default_carrier_id,
    issuablestatusid AS issuable_status_id,
    defaultpriorityid AS default_priority_id,
    defaultsalesmanid AS default_salesman_id,
    defaultshiptermsid AS default_ship_terms_id,
    defaultpaymenttermsid AS default_payment_terms_id,
    note AS customer_note,
    url AS customer_url,
    lastchangeduser AS last_changed_user
FROM 
    source_data