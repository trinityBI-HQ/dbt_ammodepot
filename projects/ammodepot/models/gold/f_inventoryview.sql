{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

SELECT
  p.part_number,
  SUM(  COALESCE(inv.quantity_on_hand,       0) ) AS qty_available,
  SUM(  COALESCE(inv.quantity_not_available, 0) ) AS qty_not_available,
  SUM(  COALESCE(inv.quantity_on_order,      0) ) AS qty_on_order,
  MAX( COALESCE(pc.average_cost, 0) )         AS part_cost,
  SUM(  COALESCE(inv.quantity_on_hand,       0) ) * MAX( COALESCE(pc.average_cost, 0) ) 
                                              AS extended_cost
FROM {{ ref('inventory_qtyinventorytotals') }} AS inv
LEFT JOIN {{ ref('fishbowl_part') }}               AS p
  ON inv.part_id = p.part_id
LEFT JOIN {{ ref('fishbowl_partcost') }}      AS pc
  ON p.part_id = pc.part_id
Where 
inv.location_group_id = 8
GROUP BY
  p.part_number

