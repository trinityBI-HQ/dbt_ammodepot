{{ config(materialized='table', schema='gold') }}
SELECT
    product_id,
    MAX(trickat) AS last_scheduled_date
FROM {{ ref('last') }}
WHERE cost > 0 AND qty_ordered > 0
GROUP BY product_id;
