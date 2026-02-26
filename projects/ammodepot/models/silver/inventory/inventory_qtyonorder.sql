with combined_on_order as (
    select
        'SO' as order_type,
        part_id,
        location_group_id,
        quantity_on_order_so as quantity_on_order -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyonorderso') }} -- Assuming this view/model exists

    union all -- Changed from UNION to UNION ALL for potential performance

    select
        'PO' as order_type,
        part_id,
        location_group_id,
        quantity_on_order_po as quantity_on_order -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyonorderpo') }} -- Assuming this view/model exists

    union all

    select
        'TO_Send' as order_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_on_order_to_send as quantity_on_order -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyonordertosend') }} -- Assuming this view/model exists

    union all

    select
        'TO_Receive' as order_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_on_order_to_receive as quantity_on_order -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyonordertoreceive') }} -- Assuming this view/model exists

    union all

    select
        'MO' as order_type,
        part_id,
        location_group_id,
        quantity_on_order_mo as quantity_on_order -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyonordermo') }} -- Assuming this view/model exists
)

select
    part_id,
    location_group_id,
    COALESCE(SUM(quantity_on_order), 0) as total_quantity_on_order
from
    combined_on_order
group by
    part_id,
    location_group_id
