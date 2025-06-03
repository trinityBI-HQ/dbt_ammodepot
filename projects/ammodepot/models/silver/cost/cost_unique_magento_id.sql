{{ config(materialized='table', schema='silver') }}
SELECT f.*
FROM {{ ref('cost_fishbowl_final') }} AS f
JOIN {{ ref('cost_aggregation') }}    AS ca ON f.id_magento = ca.id
WHERE ca.count_of_id_magento = 1;
