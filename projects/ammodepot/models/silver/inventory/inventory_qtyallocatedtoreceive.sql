with transfer_order_item_allocations as (
    select
        p.part_id,
        xo.to_location_group_id as location_group_id,
        xoi.uom_id as xo_item_uom_id,
        p.default_uom_id as part_uom_id,
        xoi.quantity_to_fulfill,
        xoi.quantity_fulfilled,
        uomc.multiply_factor,
        uomc.factor,
        uomc.uom_conversion_id
    from
        {{ ref('fishbowl_part') }} as p
    inner join
        {{ ref('fishbowl_xoitem') }} as xoi
        on p.part_id = xoi.part_id
    inner join
        {{ ref('fishbowl_xo') }} as xo
        on xo.transfer_order_id = xoi.transfer_order_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id
        and uomc.from_uom_id = xoi.uom_id
    where
        xo.status_id in (20, 30, 40, 50, 60)
        and xoi.item_status_id in (10, 20, 30, 40, 50)
        and xoi.item_type_id = 20
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when xo_item_uom_id <> part_uom_id and uom_conversion_id is not null
                then ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / NULLIF(factor, 0)
                else (quantity_to_fulfill - quantity_fulfilled)
            end
        ),
        0
    ) as quantity_allocated_to_receive
from
    transfer_order_item_allocations
group by
    part_id,
    location_group_id
