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

-- Single-scan pivot: resolve all 10 int-based EAV attributes in one pass
-- instead of 10 separate CTE+JOIN pairs that each re-scan eav_attribute_option_value
eav_option_pivot as (
    select
        cpi.entity_id,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_manufacturer') }} then eov.value end) as manufacturer,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_projectile') }} then eov.value end) as projectile,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_unit_type') }} then eov.value end) as unit_type,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcaliber') }} then eov.value end) as ddcaliber,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddaction') }} then eov.value end) as ddaction,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcondition') }} then eov.value end) as ddcondition,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddgun_parts') }} then eov.value end) as ddgun_parts,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_primary_category') }} then eov.value end) as primary_category,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcolor') }} then eov.value end) as ddcolor,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddweapons_platform') }} then eov.value end) as ddweapons_platform
    from int_entity as cpi
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on cpi.value = eov.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    where cpi.store_id = {{ var('ammodepot_default_store_id') }}
      and cpi.attribute_id in (
          {{ var('ammodepot_magento_attr_id_manufacturer') }},
          {{ var('ammodepot_magento_attr_id_projectile') }},
          {{ var('ammodepot_magento_attr_id_unit_type') }},
          {{ var('ammodepot_magento_attr_id_ddcaliber') }},
          {{ var('ammodepot_magento_attr_id_ddaction') }},
          {{ var('ammodepot_magento_attr_id_ddcondition') }},
          {{ var('ammodepot_magento_attr_id_ddgun_parts') }},
          {{ var('ammodepot_magento_attr_id_primary_category') }},
          {{ var('ammodepot_magento_attr_id_ddcolor') }},
          {{ var('ammodepot_magento_attr_id_ddweapons_platform') }}
      )
    group by cpi.entity_id
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
        {{ string_agg('eov.value', ', ', 'eov.value') }} as dd_suggested_use
    from dd_suggested_use_exploded as ex
    inner join {{ ref('magento_eav_attribute_option_value') }} as eov
        on eov.option_id = ex.option_id
        and eov.store_id = {{ var('ammodepot_default_store_id') }}
    group by ex.entity_id
)

select
    e.product_entity_id as entity_id,
    eop.manufacturer,
    eop.projectile,
    eop.unit_type,
    rpd.rounds_package,
    cap.capacity,
    mat.material,
    eop.primary_category,
    eop.ddcaliber,
    eop.ddaction,
    eop.ddcondition,
    eop.ddgun_parts,
    eop.ddcolor,
    oc.optic_coating,
    eop.ddweapons_platform,
    dsud.dd_suggested_use
from {{ ref('magento_catalog_product_entity') }} as e
left join eav_option_pivot             as eop  on e.product_entity_id = eop.entity_id
left join rounds_package_data          as rpd  on e.product_entity_id = rpd.entity_id
left join capacity_data                as cap  on e.product_entity_id = cap.entity_id
left join material_data                as mat  on e.product_entity_id = mat.entity_id
left join optic_coating_data           as oc   on e.product_entity_id = oc.entity_id
left join dd_suggested_use_data        as dsud on e.product_entity_id = dsud.entity_id
