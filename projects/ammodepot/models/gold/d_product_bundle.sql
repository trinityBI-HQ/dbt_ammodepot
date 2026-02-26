with kits as (
    -- Identify kit components and their parent kit product
    select
        kt.component_product_id,        -- from fishbowl_kititem (renamed from productid)
        kt.kit_product_id,              -- from fishbowl_kititem (renamed from kitproductid)
        pd.product_number as individual_num, -- from fishbowl_product (renamed from num)
        kt.default_quantity,            -- from fishbowl_kititem (renamed from defaultqty)
        pt.product_number as num_bundle      -- from fishbowl_product (renamed from num)
    from
        {{ ref('fishbowl_kititem') }} as kt
    left join
        {{ ref('fishbowl_product') }} as pd
        on kt.component_product_id = pd.product_id -- Use silver renamed columns
    left join
        {{ ref('fishbowl_product') }} as pt
        on kt.kit_product_id = pt.product_id -- Use silver renamed columns
    where
        kt.kit_type_id = {{ var('ammodepot_kit_type_id') }}
        and pd.product_number not like '%POLLYAMOBAG%'
        and pd.product_number not like '%POLYAMMOBAG%'
),

fishbowl_conversion_cost as (
    -- Calculate average UOM conversion factor and average cost per product number
    select
        pr.product_number,                 -- Use silver renamed column
        AVG(uom.multiply_factor) as conversion_factor, -- Use silver renamed column, better alias
        AVG(pc.average_cost) as average_cost        -- Use silver renamed column, better alias
    from
        {{ ref('fishbowl_product') }} as pr
    left join
        {{ ref('fishbowl_uomconversion') }} as uom
        on pr.uom_id = uom.from_uom_id and uom.to_uom_id = {{ var('ammodepot_base_uom_id') }}
    left join
        {{ ref('fishbowl_partcost') }} as pc
        on pr.part_id = pc.part_id -- Use silver renamed columns
    group by
        pr.product_number
)

-- Final selection combining kit info with conversion rates
select
    kt.component_product_id,
    kt.kit_product_id,
    kt.individual_num,
    kt.default_quantity,
    kt.num_bundle,
    COALESCE(fc.conversion_factor, 1) * kt.default_quantity as conversion_rate, -- Renamed alias
    'KIT' as kit_type -- Renamed alias
from
    kits as kt
left join
    fishbowl_conversion_cost as fc
    on kt.individual_num = fc.product_number
