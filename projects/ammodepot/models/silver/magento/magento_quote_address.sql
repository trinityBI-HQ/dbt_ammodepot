{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Select ALL columns from the source DDL
        fax,
        city,
        email,
        is_ffl,
        prefix,
        region,
        street,
        suffix,
        vat_id,
        weight,
        company,
        lastname,
        postcode,
        quote_id,
        subtotal,
        firstname,
        region_id,
        route_fee,
        telephone,
        address_id,
        carrier_id,
        country_id,
        created_at,
        middlename,
        tax_amount,
        updated_at,
        customer_id,
        grand_total,
        is_checkout,
        location_id,
        split_rates,
        address_type,
        carrier_type,
        vat_is_valid,
        applied_taxes,
        base_subtotal,
        free_shipping,
        customer_notes,
        smsoptin_check,
        vat_request_id,
        avatax_messages,
        aw_afptc_amount,
        base_tax_amount,
        discount_amount,
        gift_message_id,
        same_as_billing,
        shipping_amount,
        shipping_method,
        base_grand_total,
        destination_type,
        vat_request_date,
        shipping_incl_tax,
        subtotal_incl_tax,
        validation_status,
        aw_giftcard_amount,
        customer_address_id,
        shipping_tax_amount,
        vat_request_success,
        applied_restrictions,
        aw_afptc_uses_coupon,
        base_aw_afptc_amount,
        base_discount_amount,
        base_shipping_amount,
        discount_description,
        save_in_address_book,
        shipping_description,
        validated_vat_number,
        base_shipping_incl_tax,
        collect_shipping_rates,
        subtotal_with_discount,
        validated_country_code,
        base_aw_giftcard_amount,
        checkout_display_merged,
        base_shipping_tax_amount,
        shipping_discount_amount,
        carriergroup_shipping_html,
        base_subtotal_with_discount,
        base_subtotal_total_incl_tax,
        base_shipping_discount_amount,
        carriergroup_shipping_details,
        discount_tax_compensation_amount,
        base_discount_tax_compensation_amount,
        shipping_discount_tax_compensation_amount,
        base_shipping_discount_tax_compensation_amnt,

        -- Airbyte CDC columns for filtering/metadata (kept for reference if needed)
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns excluded: _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.TEST_DTO_2.QUOTE_ADDRESS
        -- Assuming you have a dbt source named 'magento' pointing to AD_AIRBYTE.TEST_DTO_2
        {{ source('magento', 'quote_address') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    address_id AS quote_address_id, -- Renamed primary key
    quote_id,
    customer_id,
    customer_address_id,
    region_id,
    country_id AS country_code, -- Assuming 2-letter code

    -- Address Details
    address_type, -- 'billing' or 'shipping'
    prefix AS name_prefix,
    firstname AS first_name,
    middlename AS middle_name,
    lastname AS last_name,
    suffix AS name_suffix,
    company,
    street AS street_address,
    city,
    region,
    postcode,
    telephone AS phone_number,
    fax AS fax_number,
    email,

    -- Financials (Quote Currency)
    subtotal,
    subtotal_incl_tax,
    subtotal_with_discount,
    grand_total,
    shipping_amount,
    shipping_incl_tax,
    shipping_tax_amount,
    tax_amount,
    discount_amount,
    discount_description,
    aw_giftcard_amount,
    aw_afptc_amount,
    shipping_discount_amount,
    discount_tax_compensation_amount,
    shipping_discount_tax_compensation_amount,

    -- Financials (Base Currency)
    base_subtotal,
    -- base_subtotal_incl_tax, -- Missing from DDL, but expected. Added base_subtotal_total_incl_tax
    base_subtotal_total_incl_tax,
    base_subtotal_with_discount,
    base_grand_total,
    base_shipping_amount,
    base_shipping_incl_tax,
    base_shipping_tax_amount,
    base_tax_amount,
    base_discount_amount,
    base_aw_giftcard_amount,
    base_aw_afptc_amount,
    base_shipping_discount_amount,
    base_discount_tax_compensation_amount,
    base_shipping_discount_tax_compensation_amnt,

    -- Shipping Details
    weight AS total_weight,
    shipping_method,
    shipping_description,
    carrier_id,
    carrier_type,
    CAST(free_shipping AS BOOLEAN) AS has_free_shipping,
    CAST(collect_shipping_rates AS BOOLEAN) AS should_collect_shipping_rates,
    applied_taxes,
    destination_type,
    carriergroup_shipping_html,
    carriergroup_shipping_details,

    -- VAT Details
    vat_id,
    CAST(vat_is_valid AS BOOLEAN) AS is_vat_valid,
    vat_request_id,
    vat_request_date, -- Keep as VARCHAR for silver
    CAST(vat_request_success AS BOOLEAN) AS was_vat_request_successful,
    validated_vat_number,
    validated_country_code,

    -- Flags & Settings
    CAST(same_as_billing AS BOOLEAN) AS is_same_as_billing,
    CAST(save_in_address_book AS BOOLEAN) AS should_save_in_address_book,
    CAST(is_ffl AS BOOLEAN) AS is_ffl_address,
    CAST(is_checkout AS BOOLEAN) AS is_checkout_address, -- Unclear meaning, kept name
    CAST(split_rates AS BOOLEAN) AS has_split_rates, -- Unclear meaning, kept name
    CAST(smsoptin_check AS BOOLEAN) AS sms_optin_check,
    validation_status,

    -- Timestamps
    created_at AS address_created_at,
    updated_at AS address_updated_at,

    -- Other
    customer_notes,
    gift_message_id,
    applied_restrictions,
    location_id,

    -- System Specific Fields (kept as requested)
    route_fee,
    avatax_messages, -- Avalara AvaTax extension
    CAST(aw_afptc_uses_coupon AS BOOLEAN) AS aw_afptc_uses_coupon, -- Advanced Promotions extension
    CAST(checkout_display_merged AS BOOLEAN) AS is_checkout_display_merged, -- Unclear meaning

    -- Airbyte CDC Metadata (kept as requested)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data