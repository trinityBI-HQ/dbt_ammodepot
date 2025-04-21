{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Identifiers
        item_id,
        order_id,
        product_id,
        parent_item_id, -- For configurable/bundle products
        quote_item_id,
        store_id,
        sku,
        ext_order_item_id, -- External Item ID if used

        -- Product Details
        name,
        description,
        product_type,
        weight, -- Individual item weight
        row_weight, -- Total weight for the row (qty * weight)
        product_options, -- Often JSON/serialized data about selected options

        -- Quantities
        qty_ordered,
        qty_shipped,
        qty_invoiced,
        qty_refunded,
        qty_canceled,
        qty_backordered,

        -- Pricing & Financials (Order Currency)
        price, -- Unit price in order currency
        original_price, -- Unit price before discounts/rules in order currency
        row_total, -- qty * price (before tax, after item discount)
        price_incl_tax, -- Unit price including tax
        row_total_incl_tax, -- Row total including tax
        tax_amount,
        tax_percent,
        discount_amount,
        discount_percent,
        amount_refunded,
        -- Consider including discount_tax_compensation_amount if used/needed

        -- Pricing & Financials (Base Currency)
        base_price, -- Unit price in base currency
        base_original_price, -- Unit price before discounts/rules in base currency
        base_row_total, -- Row total in base currency
        base_price_incl_tax, -- Unit price including tax in base currency
        base_row_total_incl_tax, -- Row total including tax in base currency
        base_tax_amount,
        base_discount_amount,
        base_amount_refunded,
        -- Consider including base_discount_tax_compensation_amount if used/needed

        -- Cost
        base_cost, -- Product cost in base currency

        -- Flags & Settings
        is_virtual,
        no_discount,
        free_shipping,
        is_qty_decimal,
        locked_do_ship,
        locked_do_invoice,
        gift_message_available,
        gift_message_id, -- Link to gift message table if needed

        -- Timestamps
        created_at,
        updated_at,

        -- Other Relevant Fields
        applied_rule_ids, -- Comma-separated list of cart price rule IDs

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT
        -- Detailed breakdown of invoiced/refunded/canceled tax/discount/row amounts (e.g., tax_invoiced, base_discount_refunded) - Keep silver simpler
        -- System-specific fields unless required (e.g., AVA_*, AW_AFPTC_*, CARRIERGROUP*, REQUIRES_FFL)
        -- additional_data (often redundant or internal info)

    FROM
        {{ source('magento', 'sales_order_item') }} -- Use the correct source name and table name
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    item_id AS order_item_id, -- Renamed primary key
    order_id,
    product_id,
    parent_item_id,
    quote_item_id,
    store_id,
    sku,
    ext_order_item_id AS external_order_item_id,

    -- Product Details
    name AS product_name,
    description AS product_description,
    product_type,
    weight AS item_weight,
    row_weight,
    product_options,

    -- Quantities
    qty_ordered,
    qty_shipped,
    qty_invoiced,
    qty_refunded,
    qty_canceled,
    qty_backordered,

    -- Pricing & Financials (Order Currency)
    price AS unit_price,
    original_price AS unit_original_price,
    row_total,
    price_incl_tax AS unit_price_incl_tax,
    row_total_incl_tax,
    tax_amount,
    tax_percent,
    discount_amount,
    discount_percent,
    amount_refunded,

    -- Pricing & Financials (Base Currency)
    base_price AS base_unit_price,
    base_original_price AS base_unit_original_price,
    base_row_total,
    base_price_incl_tax AS base_unit_price_incl_tax,
    base_row_total_incl_tax,
    base_tax_amount,
    base_discount_amount,
    base_amount_refunded,

    -- Cost
    base_cost,

    -- Flags & Settings
    CAST(is_virtual AS BOOLEAN) AS is_virtual_item,
    CAST(no_discount AS BOOLEAN) AS is_discount_excluded,
    CAST(free_shipping AS BOOLEAN) AS has_free_shipping,
    CAST(is_qty_decimal AS BOOLEAN) AS is_quantity_decimal,
    CAST(locked_do_ship AS BOOLEAN) AS is_locked_for_shipping,
    CAST(locked_do_invoice AS BOOLEAN) AS is_locked_for_invoicing,
    CAST(gift_message_available AS BOOLEAN) AS is_gift_message_available,
    gift_message_id,

    -- Timestamps
    created_at AS item_created_at, -- Rename to avoid clash with order created_at if joined
    updated_at AS item_updated_at, -- Rename to avoid clash with order updated_at if joined

    -- Other Relevant Fields
    applied_rule_ids

FROM
    source_data