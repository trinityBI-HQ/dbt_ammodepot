{{ config(materialized='table', schema='silver') }}
SELECT
    pc.produto_magento                       AS order_magento,
    AVG(fb2.freight_amount)                  AS freight_amount,
    AVG(fb2.freight_weight)                  AS freight_weight,
    AVG(fb2.carrier_service_id)              AS carrier_service_id
FROM {{ ref('fishbowl_so') }}                AS fb
LEFT JOIN {{ ref('fishbowl_shipment_costs') }} AS fb2 ON fb.sales_order_id = fb2.soid
LEFT JOIN {{ ref('conversion_so') }}         AS pc  ON fb.sales_order_id = pc.produtofish
GROUP BY pc.produto_magento;
