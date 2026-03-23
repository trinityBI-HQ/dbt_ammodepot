with source_data as (

    select
        -- Identifiers
        entity_id,         -- Primary Key for the order address itself
        parent_id,         -- Foreign Key linking to the sales_order (entity_id)
        customer_id,       -- Foreign Key linking to the customer
        customer_address_id, -- Foreign Key linking to the customer's saved address book
        quote_address_id,  -- Foreign Key linking to the quote address

        -- Address Details
        address_type,      -- Typically 'billing' or 'shipping'
        firstname,
        lastname,
        middlename,
        prefix,
        suffix,
        company,
        street,
        city,
        region,
        region_id,
        postcode,
        country_id,        -- Typically the 2-letter country code
        telephone,
        fax,
        email,

        -- VAT Information (Select based on requirements)
        vat_id,
        vat_is_valid,
        vat_request_id,
        vat_request_date,
        vat_request_success,

        -- Other Flags/Info
        smsoptin_check,     -- SMS Opt-in status
        verified_until,     -- Verification timestamp if applicable

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SALES_ORDER_ADDRESS
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('magento', 'sales_order_address') }}
    where
        -- Filter out soft deletes. This DDL correctly uses TIMESTAMP_TZ for this column.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    entity_id as order_address_id, -- Renamed primary key
    parent_id as order_id,         -- Renamed foreign key to order
    customer_id,
    customer_address_id,
    quote_address_id,

    -- Address Details
    address_type,
    firstname as first_name,
    lastname as last_name,
    middlename as middle_name,
    prefix as name_prefix,
    suffix as name_suffix,
    company,
    street as street_address,
    city,
    region,
    region_id,
    postcode,
    country_id as country_code,     -- Renamed for clarity (assuming it's the code)
    telephone as phone_number,
    fax as fax_number,
    email,

    -- VAT Information
    vat_id,
    CAST(vat_is_valid as BOOLEAN) as is_vat_valid,
    vat_request_id,
    -- CAST(vat_request_date AS TIMESTAMP) AS vat_request_date, -- Consider casting if it's a valid date string
    vat_request_date, -- Keep as string for now, transform later if needed
    CAST(vat_request_success as BOOLEAN) as was_vat_request_successful,

    -- Other Flags/Info
    smsoptin_check as sms_optin_check, -- Assuming already BOOLEAN from DDL
    verified_until

from
    source_data
