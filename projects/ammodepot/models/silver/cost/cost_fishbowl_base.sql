{{ config(materialized='table', schema='silver') }}
SELECT
    CASE WHEN s.total_cost = 0 THEN k.cost ELSE s.total_cost END           AS cost,
    m.magento_order_item_identity                                         AS magento_order,
    pr.produto_magento                                                    AS id_produto_magento,
    child.mgntid                                                          AS id_magento,
    s.so_item_id,
    s.sales_order_id,
    ca.count_of_id_magento,
    s.product_id                                                          AS id_produto_fishbowl,
    p.is_kit                                                              AS bundle,
    COALESCE(k.costprocessing, a.averagecost)                             AS averageweightedcost,
    s.scheduled_fulfillment_date,
    s.quantity_fulfilled                                                  AS qty
FROM {{ ref('fishbowl_soitem') }}            AS s
LEFT JOIN {{ ref('conversion_soitem') }}     AS child ON s.so_item_id  = child.idfb
LEFT JOIN {{ ref('product_avg_cost') }}      AS a     ON s.product_id  = a.id_produto
LEFT JOIN {{ ref('conversion_product') }}    AS pr    ON s.product_id  = pr.produtofish
LEFT JOIN {{ ref('magento_identities') }}    AS m     ON s.sales_order_id = m.code
LEFT JOIN {{ ref('cost_aggregation') }}      AS ca    ON child.mgntid  = ca.id
LEFT JOIN {{ ref('fishbowl_product') }}      AS p     ON s.product_id  = p.product_id
LEFT JOIN {{ ref('kit_cost_aggregation') }}  AS k     ON s.so_item_id  = k.kitid;
