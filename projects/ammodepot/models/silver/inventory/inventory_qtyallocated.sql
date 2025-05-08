{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH combined_allocations AS (
    SELECT
        'SO' AS allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_so AS quantity_allocated -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyallocatedso') }} -- Assuming this view/model exists

    UNION ALL -- Changed from UNION to UNION ALL for potential performance if duplicates are not expected or acceptable before aggregation

    SELECT
        'PO' AS allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_po AS quantity_allocated -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyallocatedpo') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'TO_Send' AS allocation_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_allocated_to_send AS quantity_allocated -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyallocatedtosend') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'TO_Receive' AS allocation_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_allocated_to_receive AS quantity_allocated -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyallocatedtoreceive') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'MO' AS allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_mo AS quantity_allocated -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyallocatedmo') }} -- Assuming this view/model exists
)

SELECT
    part_id,
    location_group_id,
    COALESCE(SUM(quantity_allocated), 0) AS total_quantity_allocated
FROM
    combined_allocations
GROUP BY
    part_id,
    location_group_id