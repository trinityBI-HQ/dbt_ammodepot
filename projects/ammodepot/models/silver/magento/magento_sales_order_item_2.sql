{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- All columns from the CREATE TABLE statement (excluding specific Airbyte/CDC meta)
        sku,
        name,
        price,
        vendor,
        weight,
        item_id,
        order_id,
        store_id,
        base_cost,
        row_total,
        base_price,
        created_at,
        is_virtual,
        product_id,
        row_weight,
        tax_amount,
        updated_at,
        ava_vatcode, -- Included
        description,
        no_discount,
        qty_ordered,
        qty_shipped,
        tax_percent,
        aw_afptc_qty, -- Included
        carriergroup, -- Included
        product_type,
        qty_canceled,
        qty_invoiced,
        qty_refunded,
        requires_ffl, -- Included
        row_invoiced, -- Included
        tax_canceled, -- Included
        tax_invoiced, -- Included
        tax_refunded, -- Included
        free_shipping,
        quote_item_id,
        base_row_total,
        is_qty_decimal,
        locked_do_ship,
        original_price,
        parent_item_id,
        price_incl_tax,
        additional_data, -- Included
        amount_refunded,
        aw_afptc_amount, -- Included
        base_tax_amount,
        carriergroup_id, -- Included
        discount_amount,
        gift_message_id,
        product_options,
        qty_backordered,
        applied_rule_ids,
        aw_afptc_percent, -- Included
        discount_percent,
        aw_afptc_invoiced, -- Included
        aw_afptc_is_promo, -- Included
        aw_afptc_refunded, -- Included
        aw_afptc_rule_ids, -- Included
        base_row_invoiced, -- Included
        base_tax_invoiced, -- Included
        base_tax_refunded, -- Included
        discount_invoiced, -- Included
        discount_refunded, -- Included
        ext_order_item_id,
        locked_do_invoice,
        row_total_incl_tax,
        base_original_price,
        base_price_incl_tax,
        tax_before_discount, -- Included
        base_amount_refunded,
        base_aw_afptc_amount, -- Included
        base_discount_amount,
        aw_afptc_qty_invoiced, -- Included
        aw_afptc_qty_refunded, -- Included
        carriergroup_shipping, -- Included
        base_aw_afptc_invoiced, -- Included
        base_aw_afptc_refunded, -- Included
        base_discount_invoiced, -- Included
        base_discount_refunded, -- Included
        gift_message_available,
        base_row_total_incl_tax,
        base_tax_before_discount, -- Included
        discount_tax_compensation_amount, -- Included
        discount_tax_compensation_canceled, -- Included
        discount_tax_compensation_invoiced, -- Included
        discount_tax_compensation_refunded, -- Included
        base_discount_tax_compensation_amount, -- Included
        base_discount_tax_compensation_invoiced, -- Included
        base_discount_tax_compensation_refunded, -- Included

        -- CDC Column for filtering ONLY
        _ab_cdc_deleted_at

    FROM
        -- Assuming TEST_DTO_2 schema maps to 'magento' source
        {{ source('magento', 'sales_order_item') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
        -- Filtro para ontem e hoje
        AND DATE(created_at) >= CURRENT_DATE - INTERVAL '1 DAY'
        AND DATE(created_at) <= CURRENT_DATE
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
    vendor AS vendor_id, -- Renamed to clarify it's likely an ID

    -- Product Details
    name AS product_name,
    description AS product_description,
    product_type,
    product_options,
    weight AS item_weight,
    row_weight,

    -- Quantities
    qty_ordered AS quantity_ordered,
    qty_shipped AS quantity_shipped,
    qty_invoiced AS quantity_invoiced,
    qty_refunded AS quantity_refunded,
    qty_canceled AS quantity_canceled,
    qty_backordered AS quantity_backordered,
    CAST(is_qty_decimal AS BOOLEAN) AS is_quantity_decimal,

    -- Pricing & Financials (Order Currency)
    price AS unit_price,
    original_price AS unit_original_price,
    row_total,
    price_incl_tax AS unit_price_incl_tax,
    row_total_incl_tax,
    tax_amount,
    tax_percent,
    tax_canceled,
    tax_invoiced,
    tax_refunded,
    tax_before_discount,
    discount_amount,
    discount_percent,
    discount_invoiced,
    discount_refunded,
    amount_refunded,
    row_invoiced, -- Total row amount invoiced
    discount_tax_compensation_amount,
    discount_tax_compensation_canceled,
    discount_tax_compensation_invoiced,
    discount_tax_compensation_refunded,

    -- Pricing & Financials (Base Currency)
    base_price AS base_unit_price,
    base_original_price AS base_unit_original_price,
    base_row_total,
    base_price_incl_tax AS base_unit_price_incl_tax,
    base_row_total_incl_tax,
    base_tax_amount,
    base_tax_invoiced,
    base_tax_refunded,
    base_tax_before_discount,
    base_discount_amount,
    base_discount_invoiced,
    base_discount_refunded,
    base_amount_refunded,
    base_row_invoiced, -- Total base row amount invoiced
    base_discount_tax_compensation_amount,
    base_discount_tax_compensation_invoiced,
    base_discount_tax_compensation_refunded,

    -- Cost
    base_cost,

    -- Flags & Settings
    CAST(is_virtual AS BOOLEAN) AS is_virtual_item,
    CAST(no_discount AS BOOLEAN) AS is_discount_excluded,
    CAST(free_shipping AS BOOLEAN) AS has_free_shipping,
    CAST(locked_do_ship AS BOOLEAN) AS is_locked_for_shipping,
    CAST(locked_do_invoice AS BOOLEAN) AS is_locked_for_invoicing,
    CAST(gift_message_available AS BOOLEAN) AS is_gift_message_available,
    CAST(requires_ffl AS BOOLEAN) AS requires_ffl, -- Assuming NUMBER is 0/1 flag

    -- Timestamps
    created_at AS item_created_at,
    updated_at AS item_updated_at,

    -- Other Fields (including AW_AFPTC, CARRIERGROUP, etc.)
    applied_rule_ids,
    gift_message_id,
    additional_data,
    ava_vatcode,
    -- Amasty Fields (kept as is, consider prefixing if needed)
    aw_afptc_qty,
    aw_afptc_amount,
    aw_afptc_percent,
    aw_afptc_invoiced,
    CAST(aw_afptc_is_promo AS BOOLEAN) AS is_aw_afptc_promo, -- Assuming NUMBER is 0/1 flag
    aw_afptc_refunded,
    aw_afptc_rule_ids,
    base_aw_afptc_amount,
    aw_afptc_qty_invoiced,
    aw_afptc_qty_refunded,
    base_aw_afptc_invoiced,
    base_aw_afptc_refunded,
    -- Carrier Group Fields (kept as is, consider prefixing)
    carriergroup,
    carriergroup_id,
    carriergroup_shipping

FROM
    source_data