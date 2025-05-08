{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH combined_inventory_quantities AS (

    SELECT
        'QTYONHAND' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_hand AS quantity
    FROM
        {{ ref('inventory_qtyonhand') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_hand

    UNION ALL

    -- Note: This total 'QTYALLOCATED' is selected but not used in the final CASE statements below.
    -- Included here for direct translation, but could be omitted if truly unused.
    SELECT
        'QTYALLOCATED' AS quantity_type,
        part_id,
        location_group_id,
        total_quantity_allocated AS quantity
    FROM
        {{ ref('inventory_qtyallocated') }} -- Assumes ref exists with columns part_id, location_group_id, total_quantity_allocated

    UNION ALL

    SELECT
        'QTYALLOCATEDPO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_po AS quantity
    FROM
        {{ ref('inventory_qtyallocatedpo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_po

    UNION ALL

    SELECT
        'QTYALLOCATEDSO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_so AS quantity
    FROM
        {{ ref('inventory_qtyallocatedso') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_so

    UNION ALL

    SELECT
        'QTYALLOCATEDTORECEIVE' AS quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_receive AS quantity
    FROM
        {{ ref('inventory_qtyallocatedtoreceive') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_receive

    UNION ALL

    SELECT
        'QTYALLOCATEDTOSEND' AS quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_send AS quantity
    FROM
        {{ ref('inventory_qtyallocatedtosend') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_send

    UNION ALL

    SELECT
        'QTYALLOCATEDMO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_allocated_to_mo AS quantity
    FROM
        {{ ref('inventory_qtyallocatedmo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_allocated_to_mo

    UNION ALL

    SELECT
        'QTYNOTAVAILABLE' AS quantity_type,
        part_id,
        location_group_id,
        quantity_not_available AS quantity
    FROM
        {{ ref('inventory_qtynotavailable') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_not_available

    UNION ALL

    SELECT
        'QTYNOTAVAILABLETOPICK' AS quantity_type,
        part_id,
        location_group_id,
        quantity_not_available_to_pick AS quantity
    FROM
        {{ ref('inventory_qtynotavailabletopick') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_not_available_to_pick

    UNION ALL

    SELECT
        'QTYDROPSHIP' AS quantity_type,
        part_id,
        location_group_id,
        quantity_dropship AS quantity
    FROM
        {{ ref('inventory_qtydropship') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_dropship

    UNION ALL

    SELECT
        'QTYONORDERPO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_po AS quantity
    FROM
        {{ ref('inventory_qtyonorderpo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_po

    UNION ALL

    SELECT
        'QTYONORDERSO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_so AS quantity
    FROM
        {{ ref('inventory_qtyonorderso') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_so

    UNION ALL

    SELECT
        'QTYONORDERTORECEIVE' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_to_receive AS quantity
    FROM
        {{ ref('inventory_qtyonordertoreceive') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_to_receive

    UNION ALL

    SELECT
        'QTYONORDERTOSEND' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_to_send AS quantity
    FROM
        {{ ref('inventory_qtyonordertosend') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_to_send

    UNION ALL

    SELECT
        'QTYONORDERMO' AS quantity_type,
        part_id,
        location_group_id,
        quantity_on_order_mo AS quantity
    FROM
        {{ ref('inventory_qtyonordermo') }} -- Assumes ref exists with columns part_id, location_group_id, quantity_on_order_mo
)

SELECT
    part_id,
    location_group_id,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONHAND'             THEN quantity ELSE 0 END), 0) AS quantity_on_hand,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYALLOCATEDPO'        THEN quantity ELSE 0 END), 0) AS quantity_allocated_po,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYALLOCATEDSO'        THEN quantity ELSE 0 END), 0) AS quantity_allocated_so,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYALLOCATEDMO'        THEN quantity ELSE 0 END), 0) AS quantity_allocated_mo,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYALLOCATEDTORECEIVE' THEN quantity ELSE 0 END), 0) +
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYALLOCATEDTOSEND'    THEN quantity ELSE 0 END), 0) AS quantity_allocated_transfer_order,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYNOTAVAILABLE'       THEN quantity ELSE 0 END), 0) AS quantity_not_available,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYNOTAVAILABLETOPICK' THEN quantity ELSE 0 END), 0) AS quantity_not_available_to_pick,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYDROPSHIP'           THEN quantity ELSE 0 END), 0) AS quantity_dropship,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONORDERPO'          THEN quantity ELSE 0 END), 0) AS quantity_on_order_po,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONORDERSO'          THEN quantity ELSE 0 END), 0) AS quantity_on_order_so,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONORDERTORECEIVE'   THEN quantity ELSE 0 END), 0) +
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONORDERTOSEND'      THEN quantity ELSE 0 END), 0) AS quantity_on_order_transfer_order,
    COALESCE(SUM(CASE WHEN quantity_type = 'QTYONORDERMO'          THEN quantity ELSE 0 END), 0) AS quantity_on_order_mo
FROM
    combined_inventory_quantities
GROUP BY
    part_id,
    location_group_id
