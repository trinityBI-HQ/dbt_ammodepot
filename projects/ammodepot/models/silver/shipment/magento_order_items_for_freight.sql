{{ config(materialized='table', schema='silver') }}
SELECT
    m.item_weight                    AS weight,
    m.order_id,
    m.sku,
    m.product_id,
    m.quantity_ordered               AS qty_ordered,
    CASE WHEN m.row_total = 0 THEN 0 ELSE m.quantity_ordered END AS test,
    m.row_total
        - COALESCE(m.amount_refunded,0)
        - COALESCE(m.discount_amount,0)
        + COALESCE(m.discount_refunded,0) AS row_total
FROM {{ ref('magento_sales_order_item') }} AS m
LEFT JOIN {{ ref('magento_catalog_product_entity') }} AS ct
       ON m.product_id = ct.product_entity_id
WHERE (m.row_total
          - COALESCE(m.amount_refunded,0)
          - COALESCE(m.discount_amount,0)
          + COALESCE(m.discount_refunded,0)) <> 0
  AND m.quantity_ordered <> 0
  AND ct.sku NOT ILIKE '%parceldefender%';
