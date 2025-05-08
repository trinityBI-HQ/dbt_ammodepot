{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH work_order_item_on_order AS (
    SELECT
        p.part_id,                      -- from fishbowl_part
        wo.location_group_id,           -- from fishbowl_wo
        woi.uom_id AS wo_item_uom_id,   -- from fishbowl_woitem
        p.default_uom_id AS part_uom_id,        -- from fishbowl_part
        woi.quantity_target,            -- from fishbowl_woitem
        uomc.multiply_factor,           -- from fishbowl_uomconversion
        uomc.factor,                    -- from fishbowl_uomconversion
        uomc.uom_conversion_id          -- from fishbowl_uomconversion (to check if a conversion exists)
    FROM
        {{ ref('fishbowl_part') }} p
    JOIN
        {{ ref('fishbowl_woitem') }} woi
        ON p.part_id = woi.part_id
    JOIN
        {{ ref('fishbowl_wo') }} wo
        ON wo.work_order_id = woi.work_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = woi.uom_id
    WHERE
        wo.status_id < 40
        AND woi.item_type_id IN (10, 31) -- Use renamed column
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN (wo_item_uom_id <> part_uom_id) AND (uom_conversion_id IS NOT NULL) -- Check existence of conversion
                THEN (quantity_target * multiply_factor) / factor -- Ensure factor is not zero if used in division
                ELSE quantity_target
            END
        ),
        0
    ) AS quantity_on_order_mo
FROM
    work_order_item_on_order
GROUP BY
    part_id,
    location_group_id