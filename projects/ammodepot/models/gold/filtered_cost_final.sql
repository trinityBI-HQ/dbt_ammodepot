{{ config(materialized='table', schema='gold') }}
SELECT
    product_id,
    SUM(cost) / NULLIF(SUM(qty),0) AS cost,
    SUM(qty)                       AS qty,
    trickat
FROM {{ ref('filtered_cost_prep') }}
GROUP BY product_id, trickat;
