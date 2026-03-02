with kits as (
    select
        kt.component_product_id,
        kt.kit_product_id,
        pd.product_number as individual_num,
        kt.default_quantity,
        pt.product_number as num_bundle
    from
        {{ ref('fishbowl_kititem') }} as kt
    left join
        {{ ref('fishbowl_product') }} as pd
        on kt.component_product_id = pd.product_id
    left join
        {{ ref('fishbowl_product') }} as pt
        on kt.kit_product_id = pt.product_id
    where
        kt.kit_type_id = {{ var('ammodepot_kit_type_id') }}
        and pd.product_number not like '%POLLYAMOBAG%'
        and pd.product_number not like '%POLYAMMOBAG%'
),

fishbowl_conversion_cost as (
    select
        pr.product_number,
        avg(uom.multiply_factor) as conversion_factor,
        avg(pc.average_cost) as average_cost
    from
        {{ ref('fishbowl_product') }} as pr
    left join
        {{ ref('fishbowl_uomconversion') }} as uom
        on pr.uom_id = uom.from_uom_id and uom.to_uom_id = {{ var('ammodepot_base_uom_id') }}
    left join
        {{ ref('fishbowl_partcost') }} as pc
        on pr.part_id = pc.part_id
    group by
        pr.product_number
)

select
    kt.component_product_id,
    kt.kit_product_id,
    kt.individual_num,
    kt.default_quantity,
    kt.num_bundle,
    coalesce(fc.conversion_factor, 1) * kt.default_quantity as conversion_rate,
    'KIT' as kit_type
from
    kits as kt
left join
    fishbowl_conversion_cost as fc
    on kt.individual_num = fc.product_number
