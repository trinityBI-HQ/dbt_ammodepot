{{ config(materialized='table', schema='silver') }}
SELECT
    AVG(f.cost)                AS cost,
    f.id_magento,
    AVG(f.averageweightedcost) AS averageweightedcost,
    f.id_produto_magento
FROM {{ ref('cost_fishbowl_final') }} AS f
JOIN {{ ref('cost_aggregation') }}    AS ca ON f.id_magento = ca.id
WHERE ca.count_of_id_magento > 1
GROUP BY f.id_magento, f.id_produto_magento;
