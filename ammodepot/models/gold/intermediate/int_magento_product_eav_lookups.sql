with int_entity as (
    select
        entity_id,
        attribute_id,
        store_id,
        value
    from {{ ref('magento_catalog_product_entity_int') }}
),

attribute_id_cte as (
    select
        attribute_id,
        attribute_code
    from {{ ref('magento_eav_attribute') }}
    where attribute_code in (
        'name', 'url_key', 'manufacturer_sku', 'upc', 'image', 'cost', 'price',
        'status', 'visibility', 'weight', 'manufacturer', 'attribute_set_name',
        'brand_type', 'grain_weight', 'unit_type', 'projectile', 'caliber',
        'boxes_case', 'rounds_package', 'suggested_use', 'gun_type', 'ddcaliber',
        'capacity', 'ddaction', 'ddcondition', 'material', 'ddgun_parts',
        'primary_category', 'ddcolor', 'optic_coating', 'ddweapons_platform',
        'thread_pattern', 'thread_type', 'model', 'dd_suggested_use'
    )
),

manufacturer_data as (
    select
        cpi.entity_id,
        eov.value as manufacturer
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_manufacturer') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

projectile_data as (
    select
        cpi.entity_id,
        eov.value as projectile
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_projectile') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

unit_type_data as (
    select
        cpi.entity_id,
        eov.value as unit_type
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_unit_type') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddcaliber_data as (
    select
        cpi.entity_id,
        eov.value as ddcaliber
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcaliber') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddaction_data as (
    select
        cpi.entity_id,
        eov.value as ddaction
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddaction') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddcondition_data as (
    select
        cpi.entity_id,
        eov.value as ddcondition
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcondition') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddgun_parts_data as (
    select
        cpi.entity_id,
        eov.value as ddgun_parts
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddgun_parts') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

primary_category_data as (
    select
        cpi.entity_id,
        eov.value as primary_category
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_primary_category') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddcolor_data as (
    select
        cpi.entity_id,
        eov.value as ddcolor
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcolor') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

ddweapons_platform_data as (
    select
        cpi.entity_id,
        eov.value as ddweapons_platform
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddweapons_platform') }}
        and cpi.store_id = {{ var('ammodepot_default_store_id') }}
),

rounds_package_data as (
    select
        cpv.entity_id,
        cpv.value as rounds_package
    from {{ ref('magento_catalog_product_entity_varchar') }} as cpv
    where cpv.attribute_id = {{ var('ammodepot_magento_attr_id_rounds_package') }}
        and cpv.store_id = {{ var('ammodepot_default_store_id') }}
),

capacity_data as (
    select
        cpv.entity_id,
        cpv.value as capacity
    from {{ ref('magento_catalog_product_entity_varchar') }} as cpv
    where cpv.attribute_id = {{ var('ammodepot_magento_attr_id_capacity') }}
        and cpv.store_id = {{ var('ammodepot_default_store_id') }}
),

material_data as (
    select
        cpv.entity_id,
        cpv.value as material
    from {{ ref('magento_catalog_product_entity_varchar') }} as cpv
    where cpv.attribute_id = {{ var('ammodepot_magento_attr_id_material') }}
        and cpv.store_id = {{ var('ammodepot_default_store_id') }}
),

optic_coating_data as (
    select
        cpt.entity_id,
        cpt.value as optic_coating
    from {{ ref('magento_catalog_product_entity_text') }} as cpt
    inner join attribute_id_cte as ac
        on cpt.attribute_id = ac.attribute_id
    where ac.attribute_code = 'optic_coating'
        and cpt.store_id = {{ var('ammodepot_default_store_id') }}
),

dd_suggested_use_raw as (
    select
        cpt.entity_id,
        cpt.value as raw_value
    from {{ ref('magento_catalog_product_entity_text') }} as cpt
    where cpt.attribute_id = {{ var('ammodepot_magento_attr_id_dd_suggested_use') }}
      and cpt.store_id = {{ var('ammodepot_default_store_id') }}
),

counter as (
    select 1 as n
    union all select 2
    union all select 3
    union all select 4
    union all select 5
    union all select 6
    union all select 7
    union all select 8
    union all select 9
    union all select 10
),

dd_suggested_use_exploded as (
    select
        rt.entity_id,
        case
            when regexp_like(trim(split_part(rt.raw_value, ',', c.n)), '^[0-9]+$')
            then cast(trim(split_part(rt.raw_value, ',', c.n)) as int)
            else null
        end as option_id
    from dd_suggested_use_raw as rt
    inner join counter as c on c.n <= 10
    where split_part(rt.raw_value, ',', c.n) is not null
      and regexp_like(trim(split_part(rt.raw_value, ',', c.n)), '^[0-9]+$')
),

dd_suggested_use_data as (
    select
        ex.entity_id,
        listagg(eov.value, ', ') within group (order by eov.value) as dd_suggested_use
    from dd_suggested_use_exploded as ex
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on eov.option_id = ex.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    group by ex.entity_id
)

select
    e.product_entity_id as entity_id,
    max(md.manufacturer)        as manufacturer,
    max(pd.projectile)          as projectile,
    max(utd.unit_type)          as unit_type,
    max(rpd.rounds_package)     as rounds_package,
    max(cap.capacity)           as capacity,
    max(mat.material)           as material,
    max(pc.primary_category)    as primary_category,
    max(ddc.ddcaliber)          as ddcaliber,
    max(ddact.ddaction)         as ddaction,
    max(ddcond.ddcondition)     as ddcondition,
    max(ddgp.ddgun_parts)       as ddgun_parts,
    max(dc.ddcolor)             as ddcolor,
    max(oc.optic_coating)       as optic_coating,
    max(dwp.ddweapons_platform) as ddweapons_platform,
    max(dsud.dd_suggested_use)  as dd_suggested_use
from {{ ref('magento_catalog_product_entity') }} as e
left join manufacturer_data         as md   on e.product_entity_id = md.entity_id
left join projectile_data           as pd   on e.product_entity_id = pd.entity_id
left join unit_type_data            as utd  on e.product_entity_id = utd.entity_id
left join rounds_package_data       as rpd  on e.product_entity_id = rpd.entity_id
left join capacity_data             as cap  on e.product_entity_id = cap.entity_id
left join material_data             as mat  on e.product_entity_id = mat.entity_id
left join primary_category_data     as pc   on e.product_entity_id = pc.entity_id
left join ddcaliber_data            as ddc  on e.product_entity_id = ddc.entity_id
left join ddaction_data             as ddact on e.product_entity_id = ddact.entity_id
left join ddcondition_data          as ddcond on e.product_entity_id = ddcond.entity_id
left join ddgun_parts_data          as ddgp on e.product_entity_id = ddgp.entity_id
left join ddcolor_data              as dc   on e.product_entity_id = dc.entity_id
left join optic_coating_data        as oc   on e.product_entity_id = oc.entity_id
left join ddweapons_platform_data   as dwp  on e.product_entity_id = dwp.entity_id
left join dd_suggested_use_data     as dsud on e.product_entity_id = dsud.entity_id
group by e.product_entity_id
