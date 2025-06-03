{{ config(materialized='table', schema='silver') }}
SELECT  f.record_id AS idfb,
        f.channel_id AS mgntid
FROM {{ ref('fishbowl_plugininfo') }} AS f
WHERE f.related_table_name = 'SOItem';
