{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH receipt_item_on_order AS (
    SELECT
        p.part_id,                                  -- from fishbowl_part
        r.location_group_id,                        -- from fishbowl_receipt
        ri.uom_id AS receipt_item_uom_id,           -- from fishbowl_receiptitem
        p.default_uom_id AS part_uom_id,                    -- from fishbowl_part
        ri.quantity_received,                       -- from fishbowl_receiptitem (renamed from qty)
        uomc.multiply_factor,                       -- from fishbowl_uomconversion
        uomc.factor,                                -- from fishbowl_uomconversion
        uomc.uom_conversion_id                      -- from fishbowl_uomconversion (to check if a conversion exists)
    FROM
        {{ ref('fishbowl_receipt') }} r
    JOIN
        {{ ref('fishbowl_receiptitem') }} ri -- Assuming a silver model fishbowl_receiptitem exists
        ON r.receipt_id = ri.receipt_id
    JOIN
        {{ ref('fishbowl_part') }} p
        ON p.part_id = ri.part_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = ri.uom_id
    WHERE
        r.order_type_id = 10
        AND ri.receipt_item_status_id IN (10, 20) -- Use renamed column
)

SELECT
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            CASE
                WHEN (receipt_item_uom_id <> part_uom_id) AND (uom_conversion_id IS NOT NULL) -- Check existence of conversion
                THEN (quantity_received * multiply_factor) / factor -- Ensure factor is not zero if used in division
                ELSE quantity_received
            END
        ),
        0
    ) AS quantity_on_order_po
FROM
    receipt_item_on_order
GROUP BY
    part_id,
    location_group_id