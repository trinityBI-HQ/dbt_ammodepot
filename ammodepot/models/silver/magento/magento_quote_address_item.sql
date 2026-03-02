with source_data as (

    select
        -- Select ALL columns from the source DDL
        qty,
        sku,
        name,
        image,
        price,
        weight,
        store_id,
        base_cost,
        row_total,
        base_price,
        created_at,
        product_id,
        row_weight,
        tax_amount,
        updated_at,
        description,
        no_discount,
        tax_percent,
        carriergroup,
        free_shipping,
        quote_item_id,
        base_row_total,
        is_qty_decimal,
        parent_item_id,
        price_incl_tax,
        additional_data,
        address_item_id,
        aw_afptc_amount,
        base_tax_amount,
        carriergroup_id,
        discount_amount,
        gift_message_id,
        applied_rule_ids,
        aw_afptc_percent,
        discount_percent,
        quote_address_id,
        super_product_id,
        aw_afptc_rule_ids,
        parent_product_id,
        row_total_incl_tax,
        base_price_incl_tax,
        base_aw_afptc_amount,
        base_discount_amount,
        carriergroup_shipping,
        base_row_total_incl_tax,
        row_total_with_discount,
        discount_tax_compensation_amount,
        base_discount_tax_compensation_amount,

        -- Airbyte CDC columns for filtering/metadata (kept for reference if needed)
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns excluded: _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID

    from
        {{ source('magento', 'quote_address_item') }}
    where
        _ab_cdc_deleted_at is null
)

select
     -- Identifiers
    address_item_id as quote_address_item_id, -- Renamed primary key
    quote_address_id,
    quote_item_id,
    parent_item_id,
    product_id,
    parent_product_id,
    super_product_id,
    store_id,
    sku,

    -- Item Details
    name as product_name,
    description as product_description,
    image as image_url,
    weight as item_weight,
    row_weight,
    additional_data,
    gift_message_id,

    -- Quantity
    qty as quantity,
    cast(is_qty_decimal as boolean) as is_quantity_decimal,

    -- Pricing & Financials (Quote Currency)
    price as unit_price,
    base_price, -- Unit price in base currency before conversion
    price_incl_tax as unit_price_incl_tax,
    row_total,
    row_total_incl_tax,
    row_total_with_discount,
    tax_amount,
    tax_percent,
    discount_amount,
    discount_percent,
    cast(no_discount as boolean) as is_discount_excluded,
    applied_rule_ids,
    discount_tax_compensation_amount,

    -- Pricing & Financials (Base Currency)
    base_row_total,
    base_price_incl_tax as base_unit_price_incl_tax,
    base_row_total_incl_tax,
    base_tax_amount,
    base_discount_amount,
    base_discount_tax_compensation_amount,

    -- Cost
    base_cost,

    -- Shipping
    carriergroup,
    carriergroup_id,
    cast(free_shipping as boolean) as has_free_shipping,
    carriergroup_shipping,

    -- Promotions (AW Advanced Promotions & Tier Pricing)
    aw_afptc_amount,
    aw_afptc_percent,
    aw_afptc_rule_ids,
    base_aw_afptc_amount,

    -- Timestamps
    created_at,
    updated_at,

    -- Airbyte CDC Metadata (kept as requested)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
