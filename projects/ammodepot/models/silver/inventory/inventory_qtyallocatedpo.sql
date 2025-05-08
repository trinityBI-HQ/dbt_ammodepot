{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH purchase_order_item_allocations AS (
    SELECT
        p.part_id,                                -- from fishbowl_part
        po.location_group_id,                     -- from fishbowl_po
        poi.uom_id AS po_item_uom_id,             -- from fishbowl_poitem
        p.default_uom_id AS part_uom_id,                  -- from fishbowl_part
        poi.quantity_ordered,                  -- from fishbowl_poitem
        poi.quantity_fulfilled,                   -- from fishbowl_poitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    FROM
        {{ ref('fishbowl_part') }} p
    JOIN
        {{ ref('fishbowl_poitem') }} poi -- Assuming a silver model fishbowl_poitem exists
        ON p.part_id = poi.part_id
    JOIN
        {{ ref('fishbowl_po') }} po -- Assuming a silver model fishbowl_po exists
        ON po.purchase_order_id = poi.purchase_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = poi.uom_id
    WHERE
        po.po_status_id BETWEEN 20 AND 55
        AND poi.po_item_status_id IN (10, 20, 30, 40, 45) -- Use renamed column
        AND poi.po_item_type_id IN (20, 30)             -- Use renamed column
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN (po_item_uom_id <> part_uom_id) AND (uom_conversion_id IS NOT NULL) -- Check existence of conversion
                THEN ((quantity_ordered - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                ELSE (quantity_ordered - quantity_fulfilled)
            END
        ),
        0
    ) AS quantity_allocated_to_po
FROM
    purchase_order_item_allocations
GROUP BY
    part_id,
    location_group_id
