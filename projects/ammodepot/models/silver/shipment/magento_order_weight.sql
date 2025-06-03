{{ config(materialized='table', schema='silver') }}
SELECT
    order_id,
    SUM(weight)       AS total_weight,
    COUNT(product_id) AS product_count
FROM {{ ref('magento_order_items_for_freight') }}
GROUP BY order_id;

1.2.6-- magento_order_shipping_agg.sql
{{ config(materialized='table', schema='silver') }}
SELECT
    ms.order_id,
    SUM(ms.shipping_amount)               AS shipping_amount,
    SUM(ms.base_shipping_amount)          AS base_shipping_amount,
    SUM(ms.base_shipping_canceled)        AS base_shipping_canceled,
    SUM(ms.base_shipping_discount_amount) AS base_shipping_discount_amount,
    SUM(ms.base_shipping_refunded)        AS base_shipping_refunded,
    SUM(ms.base_shipping_tax_amount)      AS base_shipping_tax_amount,
    SUM(ms.base_shipping_tax_refunded)    AS base_shipping_tax_refunded,
    SUM( COALESCE(ms.base_shipping_amount,0)
        - COALESCE(ms.base_shipping_tax_amount,0)
        - COALESCE(ms.base_shipping_refunded,0)
        + COALESCE(ms.base_shipping_tax_refunded,0)
    )                                     AS net_sales,
    SUM(mfi.freight_amount)               AS freight_amount
FROM {{ ref('magento_sales_order') }} AS ms
LEFT JOIN {{ ref('magento_freight_info') }} AS mfi ON ms.order_id = mfi.order_magento
GROUP BY ms.order_id;
