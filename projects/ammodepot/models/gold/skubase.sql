{{ config(materialized='table', schema='gold') }}
WITH base AS (
    SELECT
        ib.*,
        date_trunc('hour', ib.created_at)                           AS tiniciodahora_copiar,
        CAST(date_trunc('hour', ib.created_at) AS time)             AS tiniciodahora,
        CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END   AS ordered_no0
    FROM {{ ref('interaction_base') }} ib
)
SELECT
    b.created_at::date                    AS created_at,
    b.*,
    mo.net_sales                          AS frsales,
    mo.freight_amount                     AS fcost,
    mow.total_weight                      AS weightorder,
    mow.product_count                     AS products_in_order,
    /* % peso da linha no pedido */
    b.weight / NULLIF(mow.total_weight,0) AS percentage,
    /* freight revenue & cost (simplified as in original) */
    CASE WHEN mow.total_weight IS NULL AND b.testsku NOT ILIKE '%parceldefender%'
         THEN (b.ordered_no0 * mo.net_sales) /
              NULLIF(mow.product_count * b.ordered_no0,0)
         ELSE (b.weight * b.ordered_no0 * mo.net_sales) /
              NULLIF(mow.total_weight * b.ordered_no0,0)
    END                                   AS freight_revenue,
    CASE WHEN mow.total_weight IS NULL AND b.testsku NOT ILIKE '%parceldefender%'
         THEN (b.ordered_no0 /
              NULLIF(mow.product_count * b.ordered_no0,0)) * mo.freight_amount
         ELSE (b.weight * b.ordered_no0 /
              NULLIF(mow.total_weight * b.ordered_no0,0)) * mo.freight_amount
    END                                   AS freight_cost,
    ps.part_qty_sold,
    COALESCE(ps.conversion,1)             AS conversion
FROM base                           AS b
LEFT JOIN {{ ref('magento_order_shipping_agg') }} AS mo  ON mo.order_id = b.order_id
LEFT JOIN {{ ref('product_sales') }}           AS ps  ON ps.item_id  = b.order_item_id
LEFT JOIN {{ ref('magento_order_weight') }}    AS mow ON mow.order_id = b.order_id;
