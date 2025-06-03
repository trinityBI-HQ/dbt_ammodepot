{{ config(materialized='table', schema='silver') }}
SELECT
    fs.sales_order_id                                        AS soid,
    COALESCE(SUM(usc.net_amount), SUM(sc.freight_amount))    AS freight_amount,
    SUM(sc.freight_weight)                                   AS freight_weight,
    AVG(fs.carrier_service_id)                               AS carrier_service_id,
    SUM(usc.net_amount)                                      AS amount_ups,
    COUNT(sc.tracking_number)                                AS packagenumb
FROM {{ ref('fishbowl_ship') }}            AS fs
LEFT JOIN {{ ref('fishbowl_shipcarton') }} AS sc  ON fs.shipment_id = sc.shipment_id
LEFT JOIN {{ ref('ups_shipment_cost') }}   AS usc ON sc.tracking_number = usc.tracking_number
GROUP BY fs.sales_order_id;
