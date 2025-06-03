{{ config(materialized='table', schema='silver') }}
SELECT
    item_id,
    part_qty_sold,
    item_id          AS order_item_id,
    sku
FROM {{ ref('product_sales') }};
