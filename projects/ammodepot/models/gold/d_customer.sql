{{ config(
    materialized = 'view',
    schema       = 'gold'
) }}

SELECT
    mce.date_of_birth                          AS DOB,
    mce.email                        AS EMAIL,
    mce.gender                      AS GENDER,
    mce.name_prefix                       AS PREFIX,
    mce.name_suffix                       AS SUFFIX,
    mce.tax_vat_number                       AS TAXVAT,
    mce.customer_group_id                     AS GROUP_ID,
    mce.last_name                     AS LASTNAME,
    mce.store_id                     AS STORE_ID,
    mce.customer_id                    AS ENTITY_ID,
    mce.first_name                    AS FIRSTNAME,
    mce.is_active                    AS IS_ACTIVE,
    mce.customer_created_at                   AS CREATED_AT,
    mce.created_in_store_view                   AS CREATED_IN,
    mce.middle_name                   AS MIDDLENAME,
    mce.customer_updated_at                   AS UPDATED_AT,
    mce.website_id                   AS WEBSITE_ID,
    mce.confirmation_token                 AS CONFIRMATION,
    mce.login_failures_count                 AS FAILURES_NUM,
    mce.customer_increment_id                 AS INCREMENT_ID,
    mce.account_lock_expires_at                 AS LOCK_EXPIRES,
    mce.first_login_failure_at                AS FIRST_FAILURE,
    mce.password_hash                AS PASSWORD_HASH,
    mce._ab_cdc_cursor               AS _AB_CDC_CURSOR,
    mce.session_cutoff               AS SESSION_CUTOFF,
    mce._ab_cdc_log_pos              AS _AB_CDC_LOG_POS,
    mce.default_billing_address_id              AS DEFAULT_BILLING,
    mce.is_zendesk_user              AS IS_ZENDESK_USER,
    mce.default_shipping_address_id             AS DEFAULT_SHIPPING,
    mce.password_reset_token_created_at          AS RP_TOKEN_CREATED_AT,
    mce.is_auto_group_change_disabled    AS DISABLE_AUTO_GROUP_CHANGE,
    mce.is_mp_smtp_email_marketing_synced AS MP_SMTP_EMAIL_MARKETING_SYNCED
FROM {{ ref('magento_customer_entity') }} AS mce
