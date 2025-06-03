{{ config(materialized='table', schema='gold') }}
SELECT
    z.*,
    CASE WHEN ty.id IS NOT NULL THEN ty.row_total       ELSE z.row_total        END AS row_total,
    CASE WHEN ty.id IS NOT NULL THEN ty.cost            ELSE z.cost            END AS cost,
    CASE WHEN ty.id IS NOT NULL THEN ty.qty_ordered     ELSE z.qty_ordered     END AS qty_ordered,
    CASE WHEN ty.id IS NOT NULL THEN ty.part_qty_sold   ELSE z.part_qty_sold   END AS part_qty_sold,
    CASE WHEN ty.id IS NOT NULL THEN ty.freight_revenue ELSE z.freight_revenue END AS freight_revenue,
    CASE WHEN ty.id IS NOT NULL THEN ty.freight_cost    ELSE z.freight_cost    END AS freight_cost,
    ty.cost            AS testc,
    ty.row_total       AS testr,
    ty.freight_revenue AS testfr,
    ty.freight_cost    AS testfc
FROM {{ ref('skubase') }}             AS z
LEFT JOIN {{ ref('to_transfer') }}    AS ty ON ty.id = z.parent_item_id;
