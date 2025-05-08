{{
  config(
    materialized = 'view',
    schema       = 'silver' 
  )
}}

WITH transfer_order_item_on_order_receive AS (
    SELECT
        p.part_id,                                -- from fishbowl_part
        xo.from_location_group_id AS location_group_id, -- from fishbowl_xo (renamed fromlgid)
        xoi.uom_id AS xo_item_uom_id,             -- from fishbowl_xoitem
        p.default_uom_id AS part_uom_id,                  -- from fishbowl_part
        xoi.quantity_to_fulfill,                  -- from fishbowl_xoitem
        xoi.quantity_fulfilled,                   -- from fishbowl_xoitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    FROM
        {{ ref('fishbowl_part') }} p
    JOIN
        {{ ref('fishbowl_xoitem') }} xoi -- Assuming a silver model fishbowl_xoitem exists
        ON p.part_id = xoi.part_id
    JOIN
        {{ ref('fishbowl_xo') }} xo -- Assuming a silver model fishbowl_xo exists
        ON xo.transfer_order_id = xoi.transfer_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = xoi.uom_id
    WHERE
        xo.status_id IN (20, 30, 40, 50, 60)
        AND xoi.item_status_id IN (10, 20, 30, 40, 50) -- Use renamed column
        AND xoi.item_type_id = 20                 -- Use renamed column
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN (xo_item_uom_id <> part_uom_id) AND (uom_conversion_id IS NOT NULL) -- Check existence of conversion
                THEN ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                ELSE (quantity_to_fulfill - quantity_fulfilled)
            END
        ),
        0
    ) AS quantity_on_order_to_receive
FROM
    transfer_order_item_on_order_receive
GROUP BY
    part_id,
    location_group_id
