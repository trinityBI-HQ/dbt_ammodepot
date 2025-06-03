{{ config(materialized='table', schema='silver') }}
SELECT
    id_magento                          AS id,
    COUNT(*)                            AS count_of_id_magento,
    MAX(order_fishbowl_id)              AS order_fb
FROM {{ ref('cost_test') }}
GROUP BY id_magento;