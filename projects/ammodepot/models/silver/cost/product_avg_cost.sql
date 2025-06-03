{{ config(materialized='table', schema='silver') }}
SELECT
    p.product_id                                            AS id_produto,
    u.multiply                                              AS conversion,
    COALESCE(c.average_cost * u.multiply, c.average_cost)   AS averagecost,
    c.average_cost                                          AS costnoconversion
FROM {{ ref('fishbowl_product') }}      AS p
LEFT JOIN {{ ref('fishbowl_partcost') }} AS c ON p.part_id = c.part_id
LEFT JOIN {{ ref('uom_to_base') }}       AS u ON p.uom_id = u.fromuomid;
