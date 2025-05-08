{{ 
  config(
    materialized = 'view',
    schema = 'silver'
  ) 
}}

WITH transfer_order_item_allocations AS (
    SELECT
        p.part_id,
        xo.to_location_group_id AS location_group_id,
        xoi.uom_id AS xo_item_uom_id,
        p.default_uom_id AS part_uom_id,
        xoi.quantity_to_fulfill,
        xoi.quantity_fulfilled,
        uomc.multiply_factor,
        uomc.factor,
        uomc.uom_conversion_id
    FROM
        {{ ref('fishbowl_part') }} p
    JOIN
        {{ ref('fishbowl_xoitem') }} xoi
        ON p.part_id = xoi.part_id
    JOIN
        {{ ref('fishbowl_xo') }} xo
        ON xo.transfer_order_id = xoi.transfer_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id
        AND uomc.from_uom_id = xoi.uom_id
    WHERE
        xo.status_id IN (20, 30, 40, 50, 60)
        AND xoi.item_status_id IN (10, 20, 30, 40, 50)
        AND xoi.item_type_id = 20
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN xo_item_uom_id <> part_uom_id AND uom_conversion_id IS NOT NULL
                THEN ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / NULLIF(factor, 0)
                ELSE (quantity_to_fulfill - quantity_fulfilled)
            END
        ),
        0
    ) AS quantity_allocated_to_receive
FROM
    transfer_order_item_allocations
GROUP BY
    part_id,
    location_group_id
