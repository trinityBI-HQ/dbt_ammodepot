{{ config(materialized='table', schema='silver') }}
SELECT
    from_uom_id     AS fromuomid,
    multiply_factor AS multiply,
    to_uom_id       AS touomid
FROM {{ ref('fishbowl_uomconversion') }}
WHERE to_uom_id = 1;
