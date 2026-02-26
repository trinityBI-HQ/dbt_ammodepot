{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

with work_order_item_on_order as (
    select
        p.part_id,                      -- from fishbowl_part
        wo.location_group_id,           -- from fishbowl_wo
        woi.uom_id as wo_item_uom_id,   -- from fishbowl_woitem
        p.default_uom_id as part_uom_id,        -- from fishbowl_part
        woi.quantity_target,            -- from fishbowl_woitem
        uomc.multiply_factor,           -- from fishbowl_uomconversion
        uomc.factor,                    -- from fishbowl_uomconversion
        uomc.uom_conversion_id          -- from fishbowl_uomconversion (to check if a conversion exists)
    from
        {{ ref('fishbowl_part') }} as p
    inner join
        {{ ref('fishbowl_woitem') }} as woi
        on p.part_id = woi.part_id
    inner join
        {{ ref('fishbowl_wo') }} as wo
        on wo.work_order_id = woi.work_order_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = woi.uom_id
    where
        wo.status_id < 40
        and woi.item_type_id in (10, 31) -- Use renamed column
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when (wo_item_uom_id <> part_uom_id) and (uom_conversion_id is not null) -- Check existence of conversion
                then (quantity_target * multiply_factor) / factor -- Ensure factor is not zero if used in division
                else quantity_target
            end
        ),
        0
    ) as quantity_on_order_mo
from
    work_order_item_on_order
group by
    part_id,
    location_group_id
