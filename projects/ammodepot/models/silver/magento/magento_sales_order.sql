{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Identifiers
        entity_id,
        increment_id,
        store_id,
        customer_id,
        quote_id,
        billing_address_id,
        shipping_address_id,
        ext_order_id, -- External Order ID if used
        ext_customer_id, -- External Customer ID if used

        -- Order Status & State
        state,
        status,

        -- Timestamps
        created_at,
        updated_at,

        -- Customer Information
        customer_email,
        customer_firstname,
        customer_lastname,
        customer_prefix,
        customer_middlename,
        customer_suffix,
        customer_dob,
        customer_gender,
        customer_group_id,
        customer_is_guest,
        customer_note,
        customer_note_notify,
        customer_taxvat,

        -- Store Information
        store_name, -- Already have store_id, but name is convenient

        -- Financials (Order Currency)
        order_currency_code,
        grand_total,
        subtotal,
        subtotal_incl_tax,
        shipping_amount,
        shipping_incl_tax,
        tax_amount,
        discount_amount,
        total_paid,
        total_refunded,
        total_due,
        total_canceled,
        -- Add other specific financial fields if needed (e.g., giftcard, adjustment)
        aw_giftcard_amount,
        adjustment_positive,
        adjustment_negative,

        -- Financials (Base Currency) - Important for consistent reporting across currencies
        base_currency_code,
        base_grand_total,
        base_subtotal,
        base_subtotal_incl_tax,
        base_shipping_amount,
        base_shipping_incl_tax,
        base_tax_amount,
        base_discount_amount,
        base_total_paid,
        base_total_refunded,
        base_total_due,
        base_total_canceled,
        -- Add other base financial fields if needed
        base_aw_giftcard_amount,
        base_adjustment_positive,
        base_adjustment_negative,

        -- Shipping Details
        shipping_method,
        shipping_description,
        weight,
        total_qty_ordered,
        total_item_count,
        can_ship_partially,
        can_ship_partially_item,

        -- Billing/Payment Details
        coupon_code,
        applied_rule_ids,
        coupon_rule_name,
        discount_description,
        payment_auth_expiration,
        payment_authorization_amount,

        -- Flags & Settings
        is_virtual,
        email_sent,
        send_email, -- Often synonymous with email_sent, check Magento logic

        -- Technical/Metadata (Use cautiously)
        remote_ip,
        x_forwarded_for,
        global_currency_code,
        store_to_base_rate,
        store_to_order_rate,
        base_to_global_rate,
        base_to_order_rate,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT
        -- Detailed invoiced/refunded/canceled amounts for each component (tax, shipping, subtotal, discount)
        -- System-specific fields unless required (GA_*, ROUTE_*, AW_AFPTC_*, SPORTS_SOUTH_*, MP_SMTP_*, etc.)
        -- Relation IDs (RELATION_*) - these might be useful but add complexity

    FROM
        -- IMPORTANT: Use the correct source name ('magento') and table name ('sales_order')
        -- Assuming the table name should be 'sales_order' based on the CREATE TABLE DDL provided,
        -- even though the prompt mentioned {{ source('magento', 'store') }}
        {{ source('magento', 'sales_order') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    entity_id AS order_id, -- Renamed primary key
    increment_id AS order_increment_id, -- User-facing order number
    store_id,
    customer_id,
    quote_id,
    billing_address_id,
    shipping_address_id,
    ext_order_id AS external_order_id,
    ext_customer_id AS external_customer_id,

    -- Order Status & State
    state AS order_state,
    status AS order_status,

    -- Timestamps (assuming they are already appropriate TIMESTAMP types)
    created_at,
    updated_at,

    -- Customer Information
    customer_email,
    customer_firstname,
    customer_lastname,
    customer_prefix,
    customer_middlename,
    customer_suffix,
    customer_dob,
    customer_gender, -- Consider mapping number to string if codes are known
    customer_group_id,
    CAST(customer_is_guest AS BOOLEAN) AS is_customer_guest,
    customer_note,
    CAST(customer_note_notify AS BOOLEAN) AS should_notify_customer_note,
    customer_taxvat,

    -- Store Information
    store_name,

    -- Financials (Order Currency)
    order_currency_code,
    grand_total,
    subtotal,
    subtotal_incl_tax,
    shipping_amount,
    shipping_incl_tax,
    tax_amount,
    discount_amount,
    total_paid,
    total_refunded,
    total_due,
    total_canceled,
    aw_giftcard_amount,
    adjustment_positive,
    adjustment_negative,

    -- Financials (Base Currency)
    base_currency_code,
    base_grand_total,
    base_subtotal,
    base_subtotal_incl_tax,
    base_shipping_amount,
    base_shipping_incl_tax,
    base_tax_amount,
    base_discount_amount,
    base_total_paid,
    base_total_refunded,
    base_total_due,
    base_total_canceled,
    base_aw_giftcard_amount,
    base_adjustment_positive,
    base_adjustment_negative,

    -- Shipping Details
    shipping_method,
    shipping_description,
    weight,
    total_qty_ordered,
    total_item_count,
    CAST(can_ship_partially AS BOOLEAN) AS can_ship_partially,
    CAST(can_ship_partially_item AS BOOLEAN) AS can_ship_partially_item, -- Check if this flag logic is correct

    -- Billing/Payment Details
    coupon_code,
    applied_rule_ids, -- This might be a comma-separated string, consider parsing later if needed
    coupon_rule_name,
    discount_description,
    payment_auth_expiration, -- Consider casting to TIMESTAMP if it's a Unix timestamp or similar
    payment_authorization_amount,

    -- Flags & Settings
    CAST(is_virtual AS BOOLEAN) AS is_virtual_order,
    CAST(email_sent AS BOOLEAN) AS is_email_sent,
    CAST(send_email AS BOOLEAN) AS should_send_email, -- Clarify difference vs is_email_sent if necessary

    -- Technical/Metadata
    remote_ip,
    x_forwarded_for,
    global_currency_code,
    store_to_base_rate,
    store_to_order_rate,
    base_to_global_rate,
    base_to_order_rate

FROM
    source_data