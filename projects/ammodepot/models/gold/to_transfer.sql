{{ config(materialized='table', schema='gold') }}
SELECT
    order_item_id AS id,
    row_total,
    cost,
    freight_revenue,
    freight_cost,
    qty_ordered,
    part_qty_sold
FROM {{ ref('skubase') }}
WHERE product_type = 'configurable';
