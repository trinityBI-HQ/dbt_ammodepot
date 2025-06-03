{{ config(materialized='table', schema='silver') }}
SELECT
    COALESCE(NULLIF(b.total_cost,0), NULLIF(k.cost,0))       AS cost,
    b.total_cost                                             AS totalcost,
    k.cost                                                   AS costbundle,
    m.magento_order_item_identity                            AS magento_order,
    fc.cost                                                  AS costfiltered,
    pr.produto_magento                                       AS id_produto_magento,
    child.mgntid                                             AS id_magento,
    b.so_item_id,
    b.sales_order_id,
    ca.count_of_id_magento,
    b.product_id                                             AS id_produto_fishbowl,
    p.is_kit                                                 AS bundle,
    COALESCE(k.costprocessing, a.averagecost)                AS averageweightedcost,
    b.scheduled_fulfillment_date,
    b.quantity_fulfilled                                     AS qty
FROM {{ ref('fishbowl_soitem') }}           AS b
LEFT JOIN {{ ref('conversion_soitem') }}    AS child ON b.so_item_id  = child.idfb
LEFT JOIN {{ ref('product_avg_cost') }}     AS a     ON b.product_id  = a.id_produto
LEFT JOIN {{ ref('conversion_product') }}   AS pr    ON b.product_id  = pr.produtofish
LEFT JOIN {{ ref('magento_identities') }}   AS m     ON b.sales_order_id = m.code
LEFT JOIN {{ ref('cost_aggregation') }}     AS ca    ON child.mgntid  = ca.id
LEFT JOIN {{ ref('fishbowl_product') }}     AS p     ON b.product_id  = p.product_id
LEFT JOIN {{ ref('kit_cost_aggregation') }} AS k     ON b.so_item_id  = k.kitid
LEFT JOIN {{ ref('filtered_cost_fishbowl') }} AS fc  ON b.product_id  = fc.product_id;
