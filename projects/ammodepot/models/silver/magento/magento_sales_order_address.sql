{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
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


    FROM
        {{ source('magento', 'sales_order_address') }} -- Use the correct source name and table name
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    entity_id AS order_address_id, -- Renamed primary key
    parent_id AS order_id,         -- Renamed foreign key to order
    customer_id,
    customer_address_id,
    quote_address_id,

    -- Address Details
    address_type,
    firstname AS first_name,
    lastname AS last_name,
    middlename AS middle_name,
    prefix AS name_prefix,
    suffix AS name_suffix,
    company,
    street AS street_address,
    city,
    region,
    region_id,
    postcode,
    country_id AS country_code,     -- Renamed for clarity (assuming it's the code)
    telephone AS phone_number,
    fax AS fax_number,
    email,

    -- VAT Information
    vat_id,
    CAST(vat_is_valid AS BOOLEAN) AS is_vat_valid,
    vat_request_id,
    -- CAST(vat_request_date AS TIMESTAMP) AS vat_request_date, -- Consider casting if it's a valid date string
    vat_request_date, -- Keep as string for now, transform later if needed
    CAST(vat_request_success AS BOOLEAN) AS was_vat_request_successful,

    -- Other Flags/Info
    smsoptin_check AS sms_optin_check, -- Assuming already BOOLEAN from DDL
    verified_until


FROM
    source_data