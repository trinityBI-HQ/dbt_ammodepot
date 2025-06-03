{{ config(materialized='table', schema='silver') }}
SELECT
    NULLIF(json_extract_path_text(a.custom_fields,'Magento Order Identity 1'),'') AS magento_order_item_identity,
    a.sales_order_id AS code
FROM {{ ref('fishbowl_so') }} AS a
WHERE json_extract_path_text(a.custom_fields,'Magento Order Identity 1') IS NOT NULL;
