with combined_inventory_quantities as (

    select
        'QTYONHAND' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_hand as quantity
    from
        {{ ref('inventory_qtyonhand') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_hand

    union all

    -- Note: This total 'QTYALLOCATED' is selected but not used in the final CASE statements below.
    -- Included here for direct translation, but could be omitted if truly unused.
    select
        'QTYALLOCATED' as quantity_type,
        part_id,
        location_group_id,
        total_quantity_allocated as quantity
    from
        {{ ref('inventory_qtyallocated') }} -- Assumes ref exists with columns part_id, location_group_id, total_quantity_allocated

    union all

    select
        'QTYALLOCATEDPO' as quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_po as quantity
    from
        {{ ref('inventory_qtyallocatedpo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_po

    union all

    select
        'QTYALLOCATEDSO' as quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_so as quantity
    from
        {{ ref('inventory_qtyallocatedso') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_so

    union all

    select
        'QTYALLOCATEDTORECEIVE' as quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_receive as quantity
    from
        {{ ref('inventory_qtyallocatedtoreceive') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_receive

    union all

    select
        'QTYALLOCATEDTOSEND' as quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_send as quantity
    from
        {{ ref('inventory_qtyallocatedtosend') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_send

    union all

    select
        'QTYALLOCATEDMO' as quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_mo as quantity
    from
        {{ ref('inventory_qtyallocatedmo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_mo

    union all

    select
        'QTYNOTAVAILABLE' as quantity_type,
        part_id,
        location_group_id,
        quantity_not_available as quantity
    from
        {{ ref('inventory_qtynotavailable') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_not_available

    union all

    select
        'QTYNOTAVAILABLETOPICK' as quantity_type,
        part_id,
        location_group_id,
        quantity_not_available_to_pick as quantity
    from
        {{ ref('inventory_qtynotavailabletopick') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_not_available_to_pick

    union all

    select
        'QTYDROPSHIP' as quantity_type,
        part_id,
        location_group_id,
        quantity_dropship as quantity
    from
        {{ ref('inventory_qtydropship') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_dropship

    union all

    select
        'QTYONORDERPO' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_po as quantity
    from
        {{ ref('inventory_qtyonorderpo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_po

    union all

    select
        'QTYONORDERSO' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_so as quantity
    from
        {{ ref('inventory_qtyonorderso') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_so

    union all

    select
        'QTYONORDERTORECEIVE' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_to_receive as quantity
    from
        {{ ref('inventory_qtyonordertoreceive') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_to_receive

    union all

    select
        'QTYONORDERTOSEND' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_to_send as quantity
    from
        {{ ref('inventory_qtyonordertosend') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_to_send

    union all

    select
        'QTYONORDERMO' as quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_mo as quantity
    from
        {{ ref('inventory_qtyonordermo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_mo
)

select
    part_id,
    location_group_id,
    COALESCE(SUM(case when quantity_type = 'QTYONHAND'             then quantity else 0 end), 0) as quantity_on_hand,
    COALESCE(SUM(case when quantity_type = 'QTYALLOCATEDPO'        then quantity else 0 end), 0) as quantity_allocated_po,
    COALESCE(SUM(case when quantity_type = 'QTYALLOCATEDSO'        then quantity else 0 end), 0) as quantity_allocated_so,
    COALESCE(SUM(case when quantity_type = 'QTYALLOCATEDMO'        then quantity else 0 end), 0) as quantity_allocated_mo,
    COALESCE(SUM(case when quantity_type = 'QTYALLOCATEDTORECEIVE' then quantity else 0 end), 0)
    + COALESCE(SUM(case when quantity_type = 'QTYALLOCATEDTOSEND'    then quantity else 0 end), 0) as quantity_allocated_transfer_order,
    COALESCE(SUM(case when quantity_type = 'QTYNOTAVAILABLE'       then quantity else 0 end), 0) as quantity_not_available,
    COALESCE(SUM(case when quantity_type = 'QTYNOTAVAILABLETOPICK' then quantity else 0 end), 0) as quantity_not_available_to_pick,
    COALESCE(SUM(case when quantity_type = 'QTYDROPSHIP'           then quantity else 0 end), 0) as quantity_dropship,
    COALESCE(SUM(case when quantity_type = 'QTYONORDERPO'          then quantity else 0 end), 0) as quantity_on_order_po,
    COALESCE(SUM(case when quantity_type = 'QTYONORDERSO'          then quantity else 0 end), 0) as quantity_on_order_so,
    COALESCE(SUM(case when quantity_type = 'QTYONORDERTORECEIVE'   then quantity else 0 end), 0)
    + COALESCE(SUM(case when quantity_type = 'QTYONORDERTOSEND'      then quantity else 0 end), 0) as quantity_on_order_transfer_order,
    COALESCE(SUM(case when quantity_type = 'QTYONORDERMO'          then quantity else 0 end), 0) as quantity_on_order_mo
from
    combined_inventory_quantities
group by
    part_id,
    location_group_id
