with vendor_data as (
    select
        cpei.entity_id,
        ev.value as vendor
    from {{ ref('magento_catalog_product_entity_int') }} as cpei
    inner join {{ ref('magento_eav_attribute_option_value') }} as ev
        on cpei.value = ev.option_id
    where cpei.attribute_id = {{ var('ammodepot_magento_attr_id_vendor') }}
),

discontinued_data as (
    select
        product_entity_id,
        case
            when attribute_set_id = {{ var('ammodepot_discontinued_attribute_set_id') }} then 'Yes'
            else 'No'
        end as discontinued
    from {{ ref('magento_catalog_product_entity') }}
),

attribute_set_data as (
    select
        cpe.product_entity_id,
        eas.attribute_set_name
    from {{ ref('magento_catalog_product_entity') }} as cpe
    inner join {{ ref('magento_eav_attribute_set') }} as eas
        on cpe.attribute_set_id = eas.attribute_set_id
),

vendorpartscost as (
    select
        datelastmodified,
        partid,
        lastcost,
        ROW_NUMBER() over (partition by partid order by datelastmodified desc) as rn
    from {{ ref('fishbowl_vendor_parts') }}
),

vendorlast as (
    select
        datelastmodified,
        partid,
        lastcost
    from vendorpartscost
    where rn = 1
),

fishbowl_conversion as (
    select
        pr.product_number,
        AVG(uom.multiply_factor) as convert,
        AVG(pc.average_cost) as avgcost,
        AVG(vp.lastcost) as lastvendorcost
    from {{ ref('fishbowl_product') }} as pr
    left join {{ ref('fishbowl_uomconversion') }} as uom
        on pr.uom_id = uom.from_uom_id
        and uom.to_uom_id = {{ var('ammodepot_base_uom_id') }}
    left join {{ ref('fishbowl_partcost') }} as pc
        on pr.part_id = pc.part_id
    left join vendorlast as vp
        on pr.part_id = vp.partid
    group by pr.product_number
)

select
    e.product_entity_id as entity_id,
    e.sku,
    MAX(vd.vendor)              as vendor,
    MAX(dd.discontinued)        as discontinued,
    MAX(asd.attribute_set_name) as attribute_set_name,
    COALESCE(MAX(fbc.convert), 1) as convert,
    MAX(fbc.avgcost)            as avgcost,
    MAX(fbc.lastvendorcost)     as lastvendorcost
from {{ ref('magento_catalog_product_entity') }} as e
left join vendor_data as vd
    on e.product_entity_id = vd.entity_id
left join discontinued_data as dd
    on e.product_entity_id = dd.product_entity_id
left join attribute_set_data as asd
    on e.product_entity_id = asd.product_entity_id
left join fishbowl_conversion as fbc
    on e.sku = fbc.product_number
group by e.product_entity_id, e.sku
