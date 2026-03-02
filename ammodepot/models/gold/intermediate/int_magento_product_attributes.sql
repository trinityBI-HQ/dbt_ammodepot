with attribute_id_cte as (
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

varchar_attributes as (
    select
        cpv.entity_id,
        ac.attribute_code,
        cpv.value
    from {{ ref('magento_catalog_product_entity_varchar') }} as cpv
    inner join attribute_id_cte as ac
        on cpv.attribute_id = ac.attribute_id
    where cpv.store_id = {{ var('ammodepot_default_store_id') }}
),

text_attributes as (
    select
        cpt.entity_id,
        ac.attribute_code,
        cpt.value
    from {{ ref('magento_catalog_product_entity_text') }} as cpt
    inner join attribute_id_cte as ac
        on cpt.attribute_id = ac.attribute_id
    where cpt.store_id = {{ var('ammodepot_default_store_id') }}
),

decimal_attributes as (
    select
        cpd.entity_id,
        ac.attribute_code,
        cpd.value
    from {{ ref('magento_catalog_product_entity_decimal') }} as cpd
    inner join attribute_id_cte as ac
        on cpd.attribute_id = ac.attribute_id
    where cpd.store_id = {{ var('ammodepot_default_store_id') }}
),

all_attributes as (
    select entity_id, attribute_code, value from varchar_attributes
    union all
    select entity_id, attribute_code, value from text_attributes
    union all
    select entity_id, attribute_code, cast(value as varchar) from decimal_attributes
)

select
    entity_id,
    max(case when attribute_code = 'name'             then value end) as product_name,
    max(case when attribute_code = 'suggested_use'     then value end) as general_purpose,
    max(case when attribute_code = 'url_key'           then value end) as url_key,
    max(case when attribute_code = 'image'             then value end) as image,
    max(case when attribute_code = 'boxes_case'        then value end) as boxes_case,
    max(case when attribute_code = 'caliber'           then value end) as caliber,
    max(case when attribute_code = 'manufacturer_sku'  then value end) as manufacturer_sku,
    max(case when attribute_code = 'upc'               then value end) as upc,
    max(case when attribute_code = 'gun_type'          then value end) as gun_type,
    max(case when attribute_code = 'thread_pattern'    then value end) as thread_pattern,
    max(case when attribute_code = 'thread_type'       then value end) as thread_type,
    max(case when attribute_code = 'model'             then value end) as model
from all_attributes
group by entity_id
