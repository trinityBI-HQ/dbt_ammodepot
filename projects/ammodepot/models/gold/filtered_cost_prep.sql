{{ config(materialized='table', schema='gold') }}
SELECT
    l.product_id,
    l.cost,
    l.qty_ordered AS qty,
    l.trickat
FROM {{ ref('last') }}              AS l
JOIN {{ ref('last_day_cost_last') }} AS ld
  ON l.product_id = ld.product_id
 AND l.trickat    = ld.last_scheduled_date
WHERE l.cost > 0
  AND l.qty_ordered > 0;
