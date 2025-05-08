{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

SELECT
    part_id,
    location_group_id,
    quantity_on_hand,
    -- Calculate total allocated quantity
    (
        quantity_allocated_po +
        quantity_allocated_so +
        quantity_allocated_transfer_order +
        quantity_allocated_mo
    ) AS quantity_allocated,
    quantity_not_available,
    quantity_not_available_to_pick,
    quantity_dropship,
    -- Calculate total on order quantity
    (
        quantity_on_order_po +
        quantity_on_order_so +
        quantity_on_order_transfer_order +
        quantity_on_order_mo
    ) AS quantity_on_order
FROM
    {{ ref('inventory_qtyinventory') }} -- Reference the previous dbt model/view