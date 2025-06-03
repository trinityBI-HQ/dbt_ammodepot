{{ config(materialized='table', schema='gold') }}
SELECT
    l.created_at,
    l.timedate,
    l.order_item_id,
    l.increment_id,
    l.tiniciodahora_copiar,
    l.product_id,
    l.order_id,
    l.trickat,
    l.product_options,
    l.product_type,
    l.parent_item_id,
    l.testsku,
    l.conversion,
    l.tiniciodahora,
    l.customer_email,
    l.postcode,
    l.country,
    l.region,
    l.city,
    l.street,
    l.telephone,
    l.customer_name,
    l.store_id,
    l.status,
    l.row_total,
    COALESCE(l.cost, fcf.cost * l.qty_ordered) AS cost,
    l.qty_ordered,
    l.freight_revenue,
    l.freight_cost,
    l.testc,
    l.testr,
    l.testfr,
    l.testfc,
    l.vendor,
    l.customer_id,
    cu.rank_id,
    COALESCE(l.part_qty_sold, l.qty_ordered)   AS part_qty_sold
FROM {{ ref('last') }}                     AS l
LEFT JOIN {{ ref('filtered_cost_final') }} AS fcf ON fcf.product_id = l.product_id
LEFT JOIN {{ ref('magento_d_customerupdated') }} AS cu
  ON LOWER(COALESCE(NULLIF(l.customer_email,''),'customer@nonidentified.com')) = cu.customer_email
WHERE l.product_type <> 'configurable';
