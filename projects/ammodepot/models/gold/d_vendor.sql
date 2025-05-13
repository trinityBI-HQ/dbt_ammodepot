{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

SELECT * FROM {{ ref ("fishbowl_vendors")}}