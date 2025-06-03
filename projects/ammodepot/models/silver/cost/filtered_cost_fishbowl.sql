{{ config(materialized='table', schema='silver') }}
With  last_day_cost_fishbowl  AS (SELECT
    id_produto_fishbowl             AS product_id,
    MAX(scheduled_fulfillment_date) AS last_scheduled_date
FROM {{ ref('cost_fishbowl_base') }}
WHERE cost IS NOT NULL AND cost > 0
GROUP BY id_produto_fishbowl)

SELECT
    f.id_produto_fishbowl                  AS product_id,
    AVG(f.cost / NULLIF(f.qty,0))          AS cost
FROM {{ ref('cost_fishbowl_base') }}   AS f
JOIN {{ ref('last_day_cost_fishbowl') }} AS ld
  ON f.id_produto_fishbowl = ld.product_id
 AND f.scheduled_fulfillment_date = ld.last_scheduled_date
WHERE f.cost IS NOT NULL AND f.cost > 0
GROUP BY f.id_produto_fishbowl;
