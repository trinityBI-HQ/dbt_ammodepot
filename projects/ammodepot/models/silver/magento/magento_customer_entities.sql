{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        entity_id,
        email,
        firstname,
        lastname,
        middlename,
        prefix,
        suffix,
        dob,
        gender,
        taxvat,
        group_id,
        store_id,
        website_id,
        created_at,
        updated_at,
        is_active,
        created_in,
        default_billing,
        default_shipping,
        increment_id,
        is_zendesk_user,
        disable_auto_group_change,
        mp_smtp_email_marketing_synced
    FROM 
        {{ source('magento', 'customer_entity') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    entity_id AS customer_id,
    email AS customer_email,
    firstname AS first_name,
    lastname AS last_name,
    middlename AS middle_name,
    CASE 
        WHEN prefix IS NOT NULL AND trim(prefix) != '' THEN prefix
        ELSE NULL
    END AS name_prefix,
    CASE
        WHEN suffix IS NOT NULL AND trim(suffix) != '' THEN suffix
        ELSE NULL
    END AS name_suffix,
    dob AS date_of_birth,
    gender AS gender_id,
    CASE 
        WHEN taxvat IS NOT NULL AND trim(taxvat) != '' THEN taxvat
        ELSE NULL
    END AS tax_vat_number,
    group_id AS customer_group_id,
    store_id,
    website_id,
    created_at,
    updated_at,
    COALESCE(is_active, 0) AS is_active,
    created_in AS registration_source,
    default_billing AS default_billing_address_id,
    default_shipping AS default_shipping_address_id,
    increment_id AS customer_increment_id,
    CASE
        WHEN is_zendesk_user = '1' THEN TRUE
        WHEN is_zendesk_user = '0' THEN FALSE
        ELSE NULL
    END AS is_zendesk_user,
    disable_auto_group_change,
    mp_smtp_email_marketing_synced AS email_marketing_synced
FROM 
    source_data