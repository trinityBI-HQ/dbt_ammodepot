{{ config(materialized='table', schema='silver') }}
SELECT
    m.order_id,
    SUM(COALESCE(u.cost, d.cost))                           AS cost,
    SUM(COALESCE(u.averageweightedcost, d.averageweightedcost)) AS cost_average_order
FROM {{ ref('magento_sales_order_item') }}          AS m
LEFT JOIN {{ ref('cost_unique_magento_id') }}       AS u  ON m.order_item_id = u.id_magento
LEFT JOIN {{ ref('cost_duplicate_magento_id_product') }} AS d
       ON m.order_item_id = d.id_magento
      AND m.product_id  = d.id_produto_magento
LEFT JOIN {{ ref('cost_duplicate_magento_id_avg') }} AS a2 ON m.order_item_id = a2.id_magento
GROUP BY m.order_id;
