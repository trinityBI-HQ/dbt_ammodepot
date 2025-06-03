{{ config(materialized='table', schema='silver') }}
SELECT
    tracking_number,
    SUM(net_amount) AS net_amount
FROM {{ source('magento','ups_invoice') }}
GROUP BY tracking_number;
