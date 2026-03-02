with purchase_order_item_allocations as (
    select
        p.part_id,                                -- from fishbowl_part
        po.location_group_id,                     -- from fishbowl_po
        poi.uom_id as po_item_uom_id,             -- from fishbowl_poitem
        p.default_uom_id as part_uom_id,                  -- from fishbowl_part
        poi.quantity_ordered,                  -- from fishbowl_poitem
        poi.quantity_fulfilled,                   -- from fishbowl_poitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    from
        {{ ref('fishbowl_part') }} as p
    inner join
        {{ ref('fishbowl_poitem') }} as poi -- Assuming a silver model fishbowl_poitem exists
        on p.part_id = poi.part_id
    inner join
        {{ ref('fishbowl_po') }} as po -- Assuming a silver model fishbowl_po exists
        on po.purchase_order_id = poi.purchase_order_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = poi.uom_id
    where
        po.po_status_id between 20 and 55
        and poi.po_item_status_id in (10, 20, 30, 40, 45) -- Use renamed column
        and poi.po_item_type_id in (20, 30)             -- Use renamed column
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when (po_item_uom_id <> part_uom_id) and (uom_conversion_id is not null) -- Check existence of conversion
                then ((quantity_ordered - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                else (quantity_ordered - quantity_fulfilled)
            end
        ),
        0
    ) as quantity_allocated_to_po
from
    purchase_order_item_allocations
group by
    part_id,
    location_group_id
