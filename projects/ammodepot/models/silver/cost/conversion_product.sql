{{ config(materialized='table', schema='silver') }}
SELECT  f.record_id  AS produtofish,
        f.channel_id AS produto_magento
FROM {{ ref('fishbowl_plugininfo') }} AS f
WHERE f.related_table_name = 'Product';
