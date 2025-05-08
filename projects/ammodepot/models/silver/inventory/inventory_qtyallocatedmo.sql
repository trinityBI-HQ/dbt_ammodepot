{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

    SELECT
        p.part_id,                    
        wo.location_group_id,          
        COALESCE(
            SUM(
                CASE
                    WHEN (woi.uom_id <> p.default_uom_id) AND (uomc.uom_conversion_id IS NOT NULL)
                    THEN (woi.quantity_target * uomc.multiply_factor) / NULLIF(uomc.factor, 0)
                    ELSE woi.quantity_target
                END
            ),
            0
        ) AS quantity_allocated_to_mo    
    FROM
        {{ ref('fishbowl_part') }}              AS p
    JOIN
        {{ ref('fishbowl_woitem') }}            AS woi      ON p.part_id = woi.part_id
    JOIN
        {{ ref('fishbowl_wo') }}                AS wo       ON wo.work_order_id = woi.work_order_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }}     AS uomc     ON uomc.to_uom_id = p.default_uom_id 
        AND uomc.from_uom_id = woi.uom_id
    WHERE
        wo.status_id < 40
        AND woi.item_type_id IN (20, 30)
    GROUP BY
        p.part_id,
        wo.location_group_id
