{{ config(
    materialized = 'table',
    schema       = 'silver'
) }}

WITH source_data AS (

    SELECT
        entity_id,
        route_fee,
        base_aw_giftcard_amount,
        reserved_order_id,
        is_active,
        updated_at,
        customer_lastname,
        gift_message_id,
        customer_id,
        credova_public_id,
        aw_giftcard_amount,
        customer_taxvat,
        aw_afptc_amount,
        quote_currency_code,
        created_at,
        base_aw_afptc_amount,
        converted_at,
        route_is_insured,
        applied_rule_ids,
        customer_prefix,
        customer_dob,
        store_to_base_rate,
        items_qty,
        customer_note,
        customer_gender,
        password_hash,
        base_currency_code,
        is_virtual,
        ext_shipping_info,
        base_subtotal_with_discount,
        subtotal,
        global_currency_code,
        store_currency_code,
        base_to_quote_rate,
        remote_ip,
        orig_order_id,
        customer_note_notify,
        customer_firstname,
        customer_group_id,
        aw_afptc_uses_coupon,
        items_count,
        is_persistent,
        base_grand_total,
        is_changed,
        base_subtotal,
        customer_middlename,
        grand_total,
        base_to_global_rate,
        coupon_code,
        customer_suffix,
        customer_is_guest,
        subtotal_with_discount,
        trigger_recollect,
        checkout_method,
        route_tax_fee,
        customer_tax_class_id,
        customer_email,
        is_multi_shipping,
        store_id,
        store_to_quote_rate
    FROM {{ source('magento', 'quote') }}


)

SELECT * FROM source_data
