with dropship_item_quantities as (
    select
        p.part_id,                                -- from fishbowl_part
        so.location_group_id,                     -- from fishbowl_so
        soi.uom_id as so_item_uom_id,             -- from fishbowl_soitem
        p.default_uom_id as part_uom_id,                  -- from fishbowl_part
        soi.quantity_to_fulfill,                  -- from fishbowl_soitem
        soi.quantity_fulfilled,                   -- from fishbowl_soitem
        uomc.multiply_factor,                     -- from fishbowl_uomconversion
        uomc.factor,                              -- from fishbowl_uomconversion
        uomc.uom_conversion_id                    -- from fishbowl_uomconversion (to check if a conversion exists)
    from
        {{ ref('fishbowl_soitem') }} as soi
    inner join
        {{ ref('fishbowl_product') }} as prod -- Assuming a silver model fishbowl_product exists
        on prod.product_id = soi.product_id
    inner join
        {{ ref('fishbowl_part') }} as p
        on p.part_id = prod.part_id
    inner join
        {{ ref('fishbowl_so') }} as so -- Assuming a silver model fishbowl_so exists
        on so.sales_order_id = soi.sales_order_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = soi.uom_id
    where
        so.status_id in (20, 25)
        and soi.status_id in (10, 14, 20, 30, 40)  -- Use renamed column
        and soi.item_type_id = 12                  -- Use renamed column (assuming 12 is dropship type)
)

select
    part_id,
    location_group_id,
    COALESCE(
        SUM(
            case
                when (so_item_uom_id <> part_uom_id) and (uom_conversion_id is not null) -- Check existence of conversion
                then ((quantity_to_fulfill - quantity_fulfilled) * multiply_factor) / factor -- Ensure factor is not zero if used in division
                else (quantity_to_fulfill - quantity_fulfilled)
            end
        ),
        0
    ) as quantity_dropship
from
    dropship_item_quantities
group by
    part_id,
    location_group_id
