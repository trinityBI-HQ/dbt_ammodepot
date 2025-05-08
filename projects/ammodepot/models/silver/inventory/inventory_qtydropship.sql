{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH dropship_item_quantities AS (
    SELECT
        p.part_id,                                -- from fishbowl_part
        so.location_group_id,                     -- from fishbowl_so
        soi.uom_id AS so_item_uom_id,             -- from fishbowl_soitem
        p.default_uom_id AS part_uom_id,                  -- from fishbowl_part
        soi.quantity_to_fulfill,                  -- from fishbowl_soitem
        soi.quantity_fulfilled,                   -- from fishbowl_soitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    FROM
        {{ ref('fishbowl_soitem') }} soi
    JOIN
        {{ ref('fishbowl_product') }} prod -- Assuming a silver model fishbowl_product exists
        ON prod.product_id = soi.product_id
    JOIN
        {{ ref('fishbowl_part') }} p
        ON p.part_id = prod.part_id
    JOIN
        {{ ref('fishbowl_so') }} so -- Assuming a silver model fishbowl_so exists
        ON so.sales_order_id = soi.sales_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = soi.uom_id
    WHERE
        so.status_id IN (20, 25)
        AND soi.status_id IN (10, 14, 20, 30, 40)  -- Use renamed column
        AND soi.item_type_id = 12                  -- Use renamed column (assuming 12 is dropship type)
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN (so_item_uom_id <> part_uom_id) AND (uom_conversion_id IS NOT NULL) -- Check existence of conversion
                THEN ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                ELSE (quantity_to_fulfill - quantity_fulfilled)
            END
        ),
        0
    ) AS quantity_dropship
FROM
    dropship_item_quantities
GROUP BY
    part_id,
    location_group_id
