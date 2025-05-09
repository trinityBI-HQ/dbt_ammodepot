{{ config(
    materialized = 'view',
    schema       = 'gold'
) }}

SELECT * FROM {{ ref ("fishbowl_vendors")}}