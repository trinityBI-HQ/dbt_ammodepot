{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

SELECT
    ms.store_code       AS CODE,
    ms.store_name       AS NAME,
    ms.group_id   AS GROUP_ID,
    ms.store_id   AS STORE_ID,
    ms.is_active  AS IS_ACTIVE,
    ms.sort_order AS SORT_ORDER,
    ms.website_id AS WEBSITE_ID
FROM {{ ref('magento_store') }} AS ms
