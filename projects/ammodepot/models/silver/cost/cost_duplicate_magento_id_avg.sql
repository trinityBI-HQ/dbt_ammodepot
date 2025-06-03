{{ config(materialized='table', schema='silver') }}
SELECT
    AVG(d.cost)                AS cost,
    AVG(d.averageweightedcost) AS averageweightedcost,
    d.id_magento
FROM {{ ref('cost_duplicate_magento_id_product') }} AS d
JOIN {{ ref('magento_sales_order_item') }}          AS m
  ON d.id_magento = m.order_item_id
WHERE m.row_total <> 0
GROUP BY d.id_magento;
