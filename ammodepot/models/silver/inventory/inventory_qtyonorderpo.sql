with receipt_item_on_order as (
    select
        p.part_id,                                  -- from fishbowl_part
        r.location_group_id,                        -- from fishbowl_receipt
        ri.uom_id as receipt_item_uom_id,           -- from fishbowl_receiptitem
        p.default_uom_id as part_uom_id,                    -- from fishbowl_part
        ri.quantity_received,                       -- from fishbowl_receiptitem (renamed from qty)
        uomc.multiply_factor,                       -- from fishbowl_uomconversion
        uomc.factor,                                -- from fishbowl_uomconversion
        uomc.uom_conversion_id                      -- from fishbowl_uomconversion (to check if a conversion exists)
    from
        {{ ref('fishbowl_receipt') }} as r
    inner join
        {{ ref('fishbowl_receiptitem') }} as ri -- Assuming a silver model fishbowl_receiptitem exists
        on r.receipt_id = ri.receipt_id
    inner join
        {{ ref('fishbowl_part') }} as p
        on p.part_id = ri.part_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = ri.uom_id
    where
        r.order_type_id = 10
        and ri.receipt_item_status_id in (10, 20) -- Use renamed column
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when (receipt_item_uom_id <> part_uom_id) and (uom_conversion_id is not null) -- Check existence of conversion
                then (quantity_received * multiply_factor) / factor -- Ensure factor is not zero if used in division
                else quantity_received
            end
        ),
        0
    ) as quantity_on_order_po
from
    receipt_item_on_order
group by
    part_id,
    location_group_id
