with transfer_order_item_on_order_send as (
    select
        p.part_id,                                -- from fishbowl_part
        xo.to_location_group_id as location_group_id, -- from fishbowl_xo (renamed shiptolgid)
        xoi.uom_id as xo_item_uom_id,             -- from fishbowl_xoitem
        p.default_uom_id as part_uom_id,                  -- from fishbowl_part
        xoi.quantity_to_fulfill,                  -- from fishbowl_xoitem
        xoi.quantity_fulfilled,                   -- from fishbowl_xoitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    from
        {{ ref('fishbowl_part') }} as p
    inner join
        {{ ref('fishbowl_xoitem') }} as xoi -- Assuming a silver model fishbowl_xoitem exists
        on p.part_id = xoi.part_id
    inner join
        {{ ref('fishbowl_xo') }} as xo -- Assuming a silver model fishbowl_xo exists
        on xo.transfer_order_id = xoi.transfer_order_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = xoi.uom_id
    where
        xo.status_id in (20, 30, 40, 50, 60)
        and xoi.item_status_id in (10, 20, 30, 40, 50) -- Use renamed column
        and xoi.item_type_id = 10                 -- Use renamed column
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when (xo_item_uom_id <> part_uom_id) and (uom_conversion_id is not null) -- Check existence of conversion
                then ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                else (quantity_to_fulfill - quantity_fulfilled)
            end
        ),
        0
    ) as quantity_on_order_to_send
from
    transfer_order_item_on_order_send
group by
    part_id,
    location_group_id
