{# esse é o meu modelo silver, ajuste o schema se quiser #}
{{ 
  config(
    materialized = 'table',
    schema       = 'silver'
  ) 
}}

WITH source_data AS (

    SELECT
        dob,
        email,
        gender,
        prefix,
        suffix,
        taxvat,
        group_id,
        lastname,
        rp_token,
        store_id,
        entity_id,
        firstname,
        is_active,
        created_at,
        created_in,
        middlename,
        updated_at,
        website_id,
        confirmation,
        failures_num,
        increment_id,
        lock_expires,
        first_failure,
        password_hash,
        session_cutoff,
        default_billing,
        is_zendesk_user,
        default_shipping,
        rp_token_created_at,
        disable_auto_group_change,
        mp_smtp_email_marketing_synced,

        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

    FROM {{ source('magento', 'customer_entity') }}
    WHERE _ab_cdc_deleted_at IS NULL
)

SELECT
    entity_id                               AS customer_id,
    increment_id                            AS customer_increment_id,
    group_id                                AS customer_group_id,
    website_id,
    store_id,
    email,
    prefix                                  AS name_prefix,
    firstname                               AS first_name,
    middlename                              AS middle_name,
    lastname                                AS last_name,
    suffix                                  AS name_suffix,
    dob                                     AS date_of_birth,
    gender,
    taxvat                                  AS tax_vat_number,
    default_billing                         AS default_billing_address_id,
    default_shipping                        AS default_shipping_address_id,
    CAST(is_active AS BOOLEAN)              AS is_active,
    password_hash,
    confirmation                            AS confirmation_token,
    failures_num                            AS login_failures_count,
    first_failure                           AS first_login_failure_at,
    lock_expires                            AS account_lock_expires_at,
    rp_token                                AS password_reset_token,
    rp_token_created_at                     AS password_reset_token_created_at,
    created_at                              AS customer_created_at,
    updated_at                              AS customer_updated_at,
    created_in                              AS created_in_store_view,
    session_cutoff,
    CAST(disable_auto_group_change AS BOOLEAN)        AS is_auto_group_change_disabled,
    is_zendesk_user                AS is_zendesk_user,
    CAST(mp_smtp_email_marketing_synced AS BOOLEAN)  AS is_mp_smtp_email_marketing_synced,
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at
FROM source_data
