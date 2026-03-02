with combined_allocations as (
    select
        'SO' as allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_so as quantity_allocated -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyallocatedso') }} -- Assuming this view/model exists

    union all -- Changed from UNION to UNION ALL for potential performance if duplicates are not expected or acceptable before aggregation

    select
        'PO' as allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_po as quantity_allocated -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyallocatedpo') }} -- Assuming this view/model exists

    union all

    select
        'TO_Send' as allocation_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_allocated_to_send as quantity_allocated -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyallocatedtosend') }} -- Assuming this view/model exists

    union all

    select
        'TO_Receive' as allocation_type, -- Standardized naming
        part_id,
        location_group_id,
        quantity_allocated_to_receive as quantity_allocated -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyallocatedtoreceive') }} -- Assuming this view/model exists

    union all

    select
        'MO' as allocation_type,
        part_id,
        location_group_id,
        quantity_allocated_to_mo as quantity_allocated -- Use renamed column from the ref model
    from
        {{ ref('inventory_qtyallocatedmo') }} -- Assuming this view/model exists
)

select
    part_id,
    location_group_id,
    COALESCE(SUM(quantity_allocated), 0) as total_quantity_allocated
from
    combined_allocations
group by
    part_id,
    location_group_id
