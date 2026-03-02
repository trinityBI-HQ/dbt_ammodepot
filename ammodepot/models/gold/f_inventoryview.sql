select
  p.part_number,
  sum(  coalesce(inv.quantity_on_hand,       0) ) as qty_available,
  sum(  coalesce(inv.quantity_not_available, 0) ) as qty_not_available,
  sum(  coalesce(inv.quantity_on_order,      0) ) as qty_on_order,
  max( coalesce(pc.average_cost, 0) )         as part_cost,
  sum(  coalesce(inv.quantity_on_hand,       0) ) * max( coalesce(pc.average_cost, 0) )
                                              as extended_cost
from {{ ref('inventory_qtyinventorytotals') }} as inv
left join {{ ref('fishbowl_part') }}               as p
  on inv.part_id = p.part_id
left join {{ ref('fishbowl_partcost') }}      as pc
  on p.part_id = pc.part_id
where
inv.location_group_id = {{ var('ammodepot_default_location_group_id') }}
group by
  p.part_number
