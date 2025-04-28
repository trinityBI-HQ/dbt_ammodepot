{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}
with attribute_id_cte as (
    select attribute_id, attribute_code
    from {{ ref('magento_eav_attribute') }}
    where attribute_code in (
        'name', 'url_key', 'manufacturer_sku', 'upc', 'image', 'cost', 'price',
        'status', 'visibility', 'weight', 'manufacturer', 'attribute_set_name',
        'brand_type', 'grain_weight', 'unit_type', 'projectile', 'caliber',
        'boxes_case', 'rounds_package', 'suggested_use', 'gun_type', 'ddcaliber',
        'capacity', 'ddaction', 'ddcondition', 'material', 'ddgun_parts',
        'primary_category', 'ddcolor', 'optic_coating', 'ddweapons_platform',
        'thread_pattern', 'thread_type', 'model'
    )
),

test1 as (
    select *
    from {{ ref('magento_catalog_product_entity_int') }}

),

varchar_attributes as (
    select
        cpv.entity_id,
        ac.attribute_code,
        cpv.value
    from {{ ref('magento_catalog_product_entity_varchar') }} cpv
    join attribute_id_cte ac
      on cpv.attribute_id = ac.attribute_id
    where cpv.store_id = 0
),

text_attributes as (
    select
        cpt.entity_id,
        ac.attribute_code,
        cpt.value
    from {{ ref('magento_catalog_product_entity_text') }} cpt
    join attribute_id_cte ac
      on cpt.attribute_id = ac.attribute_id
    where cpt.store_id = 0
),

int_attributes as (
    select
        cpi.entity_id,
        ac.attribute_code,
        cpi.value
    from test1 cpi
    join attribute_id_cte ac
      on cpi.attribute_id = ac.attribute_id
    where cpi.store_id = 0
),

decimal_attributes as (
    select
        cpd.entity_id,
        ac.attribute_code,
        cpd.value
    from {{ ref('magento_catalog_product_entity_decimal') }} cpd
    join attribute_id_cte ac
      on cpd.attribute_id = ac.attribute_id
    where cpd.store_id = 0
),

category_data as (
    select
        ccp.product_id,
        listagg(ccv.value, ' > ') within group (order by ccv.value) as categories
    from {{ ref('magento_catalog_category_product') }} ccp
    join {{ ref('magento_catalog_category_entity_varchar') }} ccv
      on ccp.category_id = ccv.entity_id
    join attribute_id_cte ac
      on ccv.attribute_id = ac.attribute_id
     and ac.attribute_code = 'name'
    group by ccp.product_id
),

parent_sku_data as (
    select
        sl.product_id,
        parent.sku as parent_sku
    from {{ ref('magento_catalog_product_super_link') }} sl
    join {{ ref('magento_catalog_product_entity') }} parent
      on sl.parent_id = parent.product_entity_id
),

discontinued_data as (
    select
        product_entity_id,
        case when attribute_set_id = 50 then 'Yes' else 'No' end as discontinued
    from {{ ref('magento_catalog_product_entity') }}
),

manufacturer_data as (
    select
        cpi.entity_id,
        eov.value as manufacturer
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 677
      and cpi.store_id = 0
),

projectile_data as (
    select
        cpi.entity_id,
        eov.value as projectile
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 681
      and cpi.store_id = 0
),

unit_type_data as (
    select
        cpi.entity_id,
        eov.value as unit_type
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 649
      and cpi.store_id = 0
),

ddcaliber_data as (
    select
        cpi.entity_id,
        eov.value as ddcaliber
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 678
      and cpi.store_id = 0
),

ddaction_data as (
    select
        cpi.entity_id,
        eov.value as ddaction
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 718
      and cpi.store_id = 0
),

ddcondition_data as (
    select
        cpi.entity_id,
        eov.value as ddcondition
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 676
      and cpi.store_id = 0
),

ddgun_parts_data as (
    select
        cpi.entity_id,
        eov.value as ddgun_parts
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 817
      and cpi.store_id = 0
),

rounds_package_data as (
    select
        cpv.entity_id,
        cpv.value as rounds_package
    from {{ ref('magento_catalog_product_entity_varchar') }} cpv
    where cpv.attribute_id = 152
      and cpv.store_id = 0
),

capacity_data as (
    select
        cpv.entity_id,
        cpv.value as capacity
    from {{ ref('magento_catalog_product_entity_varchar') }} cpv
    where cpv.attribute_id = 165
      and cpv.store_id = 0
),

vendor_data as (
    select
        cpei.entity_id,
        ev.value as vendor
    from test1 cpei
    join {{ ref('magento_eav_attribute_option_value') }} ev
      on cpei.value = ev.option_id

    where cpei.attribute_id = 145
),

material_data as (
    select
        cpv.entity_id,
        cpv.value as material
    from {{ ref('magento_catalog_product_entity_varchar') }} cpv
    where cpv.attribute_id = 188
      and cpv.store_id = 0
),

attribute_set_data as (
    select
        cpe.product_entity_id,
        eas.attribute_set_name
    from {{ ref('magento_catalog_product_entity') }} cpe
    join {{ ref('magento_eav_attribute_set') }} eas
      on cpe.attribute_set_id = eas.attribute_set_id
),

primary_category_data as (
    select
        cpi.entity_id,
        eov.value as primary_category
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 878
      and cpi.store_id = 0
),

ddcolor_data as (
    select
        cpi.entity_id,
        eov.value as ddcolor
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 685
      and cpi.store_id = 0
),

optic_coating_data as (
    select
        cpt.entity_id,
        cpt.value as optic_coating
    from {{ ref('magento_catalog_product_entity_text') }} cpt
    join attribute_id_cte ac
      on cpt.attribute_id = ac.attribute_id
    where ac.attribute_code = 'optic_coating'
      and cpt.store_id = 0
),

ddweapons_platform_data as (
    select
        cpi.entity_id,
        eov.value as ddweapons_platform
    from test1 cpi
    join {{ ref('magento_eav_attribute_option_value') }} eov
      on cpi.value = eov.option_id
     and eov.store_id = 0

    where cpi.attribute_id = 756
      and cpi.store_id = 0
)

select
    e.product_entity_id    as product_id,
    e.sku,
    max(case when va.attribute_code = 'name'           then va.value end) as product_name,
    max(case when va.attribute_code = 'suggested_use'  then va.value end) as general_purpose,
    max(case when va.attribute_code = 'url_key'        then concat('https://www.ammunitiondepot.com/', va.value) end) as product_url,
    max(case when va.attribute_code = 'image'          then concat('https://www.ammunitiondepot.com/media/catalog/product', va.value) end) as product_image_url,
    vd.vendor    as vendor,
    dd.discontinued as discontinued,
    psd.parent_sku as parent_sku,
    coalesce(psd.parent_sku, e.sku) as grouped_sku,
    max(case when va.attribute_code = 'boxes_case'     then va.value end) as boxes_case,
    max(case when va.attribute_code = 'caliber'        then va.value end) as caliber,
    max(case when va.attribute_code = 'manufacturer_sku' then va.value end) as manufacturer_sku,
    max(case when va.attribute_code = 'upc'            then va.value end) as upc,
    max(md.manufacturer)   as manufacturer,
    max(pd.projectile)     as projectile,
    max(utd.unit_type)     as unit_type,
    max(rpd.rounds_package) as rounds_package,
    max(asd.attribute_set_name) as attribute_set,
    cd.categories          as categories,
    max(case when va.attribute_code = 'gun_type'      then va.value end) as gun_type,
    max(ddc.ddcaliber)     as ddcaliber,
    max(ddact.ddaction)    as ddaction,
    max(ddcond.ddcondition) as ddcondition,
    max(ddgp.ddgun_parts)  as ddgun_parts,
    max(capacity.capacity) as capacity,
    max(material.material) as material,
    max(pc.primary_category) as primary_category,
    max(dc.ddcolor)         as ddcolor,
    max(oc.optic_coating)   as optic_coating,
    max(dwp.ddweapons_platform) as ddweapons_platform,
    max(case when va.attribute_code = 'thread_pattern' then va.value end) as thread_pattern,
    max(case when va.attribute_code = 'thread_type'    then va.value end) as thread_type,
    max(case when va.attribute_code = 'model'          then va.value end) as model
from {{ ref('magento_catalog_product_entity') }} e
left join varchar_attributes va on e.product_entity_id = va.entity_id
left join int_attributes ia    on e.product_entity_id = ia.entity_id
left join decimal_attributes da on e.product_entity_id = da.entity_id
left join text_attributes ta   on e.product_entity_id = ta.entity_id
left join category_data cd     on e.product_entity_id = cd.product_id
left join vendor_data vd       on e.product_entity_id = vd.entity_id
left join parent_sku_data psd  on e.product_entity_id = psd.product_id
left join discontinued_data dd on e.product_entity_id = dd.product_entity_id
left join manufacturer_data md on e.product_entity_id = md.entity_id
left join projectile_data pd   on e.product_entity_id = pd.entity_id
left join unit_type_data utd   on e.product_entity_id = utd.entity_id
left join ddcaliber_data ddc   on e.product_entity_id = ddc.entity_id
left join ddaction_data ddact  on e.product_entity_id = ddact.entity_id
left join ddcondition_data ddcond on e.product_entity_id = ddcond.entity_id
left join ddgun_parts_data ddgp  on e.product_entity_id = ddgp.entity_id
left join rounds_package_data rpd on e.product_entity_id = rpd.entity_id
left join capacity_data capacity  on e.product_entity_id = capacity.entity_id
left join material_data material  on e.product_entity_id = material.entity_id
left join attribute_set_data asd  on e.product_entity_id = asd.product_entity_id
left join primary_category_data pc on e.product_entity_id = pc.entity_id
left join ddcolor_data dc     on e.product_entity_id = dc.entity_id
left join optic_coating_data oc on e.product_entity_id = oc.entity_id
left join ddweapons_platform_data dwp on e.product_entity_id = dwp.entity_id
group by 
    e.product_entity_id,
    e.sku,
    cd.categories,
    vd.vendor,
    dd.discontinued,
    psd.parent_sku

