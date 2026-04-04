select
        p.part_id,
        wo.location_group_id,
        COALESCE(
            SUM(
                case
                    when (woi.uom_id <> p.default_uom_id) and (uomc.uom_conversion_id is not null)
                    then (woi.quantity_target * uomc.multiply_factor) / NULLIF(uomc.factor, 0)
                    else woi.quantity_target
                end
            ),
            0
        ) as quantity_allocated_to_mo
    from
        {{ ref('fishbowl_part') }}              as p
    inner join
        {{ ref('fishbowl_woitem') }}            as woi      on p.part_id = woi.part_id
    inner join
        {{ ref('fishbowl_wo') }}                as wo       on wo.work_order_id = woi.work_order_id
    left join
        {{ ref('fishbowl_uomconversion') }}     as uomc     on uomc.to_uom_id = p.default_uom_id
        and uomc.from_uom_id = woi.uom_id
    where
        wo.status_id < 40
        and woi.item_type_id in (20, 30)
    group by
        p.part_id,
        wo.location_group_id
