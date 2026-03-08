with source_data as (

    select
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

    from {{ source('magento', 'customer_entity') }}
    where _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by entity_id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    entity_id                               as customer_id,
    increment_id                            as customer_increment_id,
    group_id                                as customer_group_id,
    website_id,
    store_id,
    email,
    prefix                                  as name_prefix,
    firstname                               as first_name,
    middlename                              as middle_name,
    lastname                                as last_name,
    suffix                                  as name_suffix,
    dob                                     as date_of_birth,
    gender,
    taxvat                                  as tax_vat_number,
    default_billing                         as default_billing_address_id,
    default_shipping                        as default_shipping_address_id,
    cast(is_active as boolean)              as is_active,
    password_hash,
    confirmation                            as confirmation_token,
    failures_num                            as login_failures_count,
    first_failure                           as first_login_failure_at,
    lock_expires                            as account_lock_expires_at,
    rp_token                                as password_reset_token,
    rp_token_created_at                     as password_reset_token_created_at,
    created_at                              as customer_created_at,
    updated_at                              as customer_updated_at,
    created_in                              as created_in_store_view,
    session_cutoff,
    cast(disable_auto_group_change as boolean)        as is_auto_group_change_disabled,
    is_zendesk_user                as is_zendesk_user,
    cast(mp_smtp_email_marketing_synced as boolean)  as is_mp_smtp_email_marketing_synced,
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at
from source_data
