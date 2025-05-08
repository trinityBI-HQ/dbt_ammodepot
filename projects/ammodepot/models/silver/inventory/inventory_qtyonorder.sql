{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

WITH combined_on_order AS (
    SELECT
        'SO' AS order_type,
        part_id,
        location_group_id,
        quantity_on_order_so AS quantity_on_order -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyonorderso') }} -- Assuming this view/model exists

    UNION ALL -- Changed from UNION to UNION ALL for potential performance

    SELECT
        'PO' AS order_type,
        part_id,
        location_group_id,
        quantity_on_order_po AS quantity_on_order -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyonorderpo') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'TO_Send' AS order_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_on_order_to_send AS quantity_on_order -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyonordertosend') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'TO_Receive' AS order_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_on_order_to_receive AS quantity_on_order -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyonordertoreceive') }} -- Assuming this view/model exists

    UNION ALL

    SELECT
        'MO' AS order_type,
        part_id,
        location_group_id,
        quantity_on_order_mo AS quantity_on_order -- Use renamed column from the ref model
    FROM
        {{ ref('inventory_qtyonordermo') }} -- Assuming this view/model exists
)

SELECT
    part_id,
    location_group_id,
    COALESCE(SUM(quantity_on_order), 0) AS total_quantity_on_order
FROM
    combined_on_order
GROUP BY
    part_id,
    location_group_id
