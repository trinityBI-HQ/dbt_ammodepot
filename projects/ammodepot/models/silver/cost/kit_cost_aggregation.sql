{{ config(materialized='table', schema='silver') }}
SELECT
    COALESCE(
        NULLIF(SUM(CAST(s.total_cost AS DECIMAL(38,9))),0),
        SUM(CAST(s.quantity_ordered AS DECIMAL(38,9)) * CAST(a.averagecost AS DECIMAL(38,9)))
    )                               AS cost,
    k.recordid2                      AS kitid,
    SUM(a.averagecost)               AS costprocessing,
    MAX(s.quantity_ordered)          AS maxqtytest
FROM {{ ref('fishbowl_soitem') }} AS s
LEFT JOIN {{ ref('product_avg_cost') }} AS a ON s.product_id = a.id_produto
LEFT JOIN {{ ref('object_kit') }}     AS k ON s.so_item_id = k.recordid1
WHERE s.item_type_id = 10
  AND s.product_description NOT ILIKE '%POLLYAMOBAG%'
GROUP BY k.recordid2;
