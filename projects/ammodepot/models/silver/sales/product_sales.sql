{{ config(materialized='table', schema='silver') }}
SELECT
    s.order_item_id                                           AS item_id,
    SUM(s.quantity_ordered * COALESCE(uom.multiply_factor,1)) AS part_qty_sold,
    AVG(COALESCE(uom.multiply_factor,1))                      AS conversion,
    cpe.sku
FROM {{ ref('magento_sales_order_item') }} AS s
JOIN {{ ref('magento_sales_order') }}      AS o   ON s.order_id = o.order_id
JOIN {{ ref('magento_catalog_product_entity') }} AS cpe ON s.product_id = cpe.product_entity_id
JOIN {{ ref('fishbowl_product') }}         AS pr  ON cpe.sku = pr.product_number
JOIN {{ ref('fishbowl_part') }}            AS p   ON pr.part_id = p.part_id
LEFT JOIN {{ ref('fishbowl_uomconversion') }} AS uom
       ON s.product_id = uom.from_uom_id
      AND uom.to_uom_id = 1
WHERE s.product_type <> 'bundle'
  AND s.row_total <> 0
GROUP BY s.order_item_id, cpe.sku;
