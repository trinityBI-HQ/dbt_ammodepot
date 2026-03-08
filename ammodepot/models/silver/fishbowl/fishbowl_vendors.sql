with source_data as (
    select
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
    from
        {{ source('fishbowl', 'vendor') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    id as vendor_id,
    name as vendor_name,
    note as vendor_note,
    url as vendor_url,
    leadtime as lead_time_days,
    statusid as status_id,
    accountid as account_id,
    sysuserid as sysuser_id,
    taxrateid as tax_rate_id,
    accountnum as account_number,
    activeflag as is_active,
    currencyid as currency_id,
    creditlimit as credit_limit,
    dateentered as date_entered,
    accountingid as accounting_id,
    currencyrate as currency_rate,
    customfields as custom_fields,
    accountinghash as accounting_hash,
    minorderamount as minimum_order_amount,
    lastchangeduser as last_changed_user,
    datelastmodified as date_last_modified,
    defaultcarrierid as default_carrier_id,
    defaultshiptermsid as default_ship_terms_id,
    defaultpaymenttermsid as default_payment_terms_id,
    defaultcarrierserviceid as default_carrier_service_id
from
    source_data
