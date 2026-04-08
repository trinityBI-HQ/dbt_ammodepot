{# Resolves Magento EAV product attributes for d_product. Optimized to:
   1. Single-scan each underlying EAV value table (int / varchar / text)
      via MAX(CASE WHEN ...) pivots — no per-attribute CTE+JOIN pairs.
   2. Filter the option-value lookup once and reuse it across both the
      int pivot and dd_suggested_use explosion.
   3. Replace the manual 1..10 counter + split_part loop with a native
      LATERAL FLATTEN(SPLIT(...)) for dd_suggested_use parsing — no
      element-count cap and no repeated string scans. #}

with product_entity as (
    select
        product_entity_id
    from {{ ref('magento_catalog_product_entity') }}
),

cpe_int as (
    select
        entity_id,
        attribute_id,
        value
    from {{ ref('magento_catalog_product_entity_int') }}
    where store_id = {{ var('ammodepot_default_store_id') }}
      and attribute_id in (
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
),

cpe_varchar as (
    select
        entity_id,
        attribute_id,
        value
    from {{ ref('magento_catalog_product_entity_varchar') }}
    where store_id = {{ var('ammodepot_default_store_id') }}
      and attribute_id in (
          {{ var('ammodepot_magento_attr_id_rounds_package') }},
          {{ var('ammodepot_magento_attr_id_capacity') }},
          {{ var('ammodepot_magento_attr_id_material') }}
      )
),

optic_coating_attr as (
    select
        attribute_id
    from {{ ref('magento_eav_attribute') }}
    where attribute_code = 'optic_coating'
),

cpe_text as (
    select
        cpt.entity_id,
        cpt.attribute_id,
        cpt.value
    from {{ ref('magento_catalog_product_entity_text') }} as cpt
    left join optic_coating_attr as oca
        on cpt.attribute_id = oca.attribute_id
    where cpt.store_id = {{ var('ammodepot_default_store_id') }}
      and (
          cpt.attribute_id = {{ var('ammodepot_magento_attr_id_dd_suggested_use') }}
          or oca.attribute_id is not null
      )
),

option_value as (
    select
        option_id,
        value
    from {{ ref('magento_eav_attribute_option_value') }}
    where store_id = {{ var('ammodepot_default_store_id') }}
),

{# Single-scan pivot for all 10 int-based option-id attributes. #}
int_pivot as (
    select
        cpi.entity_id,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_manufacturer') }}        then ov.value end) as manufacturer,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_projectile') }}          then ov.value end) as projectile,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_unit_type') }}           then ov.value end) as unit_type,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcaliber') }}           then ov.value end) as ddcaliber,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddaction') }}            then ov.value end) as ddaction,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcondition') }}         then ov.value end) as ddcondition,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddgun_parts') }}         then ov.value end) as ddgun_parts,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_primary_category') }}    then ov.value end) as primary_category,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddcolor') }}             then ov.value end) as ddcolor,
        max(case when cpi.attribute_id = {{ var('ammodepot_magento_attr_id_ddweapons_platform') }}  then ov.value end) as ddweapons_platform
    from cpe_int as cpi
    inner join option_value as ov
        on cpi.value = ov.option_id
    group by cpi.entity_id
),

{# Single-scan pivot for all 3 varchar attributes. #}
varchar_pivot as (
    select
        cpv.entity_id,
        max(case when cpv.attribute_id = {{ var('ammodepot_magento_attr_id_rounds_package') }} then cpv.value end) as rounds_package,
        max(case when cpv.attribute_id = {{ var('ammodepot_magento_attr_id_capacity') }}       then cpv.value end) as capacity,
        max(case when cpv.attribute_id = {{ var('ammodepot_magento_attr_id_material') }}      then cpv.value end) as material
    from cpe_varchar as cpv
    group by cpv.entity_id
),

optic_coating_data as (
    select
        cpt.entity_id,
        cpt.value as optic_coating
    from cpe_text as cpt
    inner join optic_coating_attr as oca
        on cpt.attribute_id = oca.attribute_id
),

{# dd_suggested_use is a comma-separated list of option_ids stored as text.
   LATERAL FLATTEN explodes it natively (no 10-element cap, single scan). #}
dd_suggested_use_exploded as (
    select
        cpt.entity_id,
        try_to_number(trim(f.value::string)) as option_id
    from cpe_text as cpt,
        lateral flatten(input => split(cpt.value, ',')) as f
    where cpt.attribute_id = {{ var('ammodepot_magento_attr_id_dd_suggested_use') }}
      and try_to_number(trim(f.value::string)) is not null
),

dd_suggested_use_data as (
    select
        ex.entity_id,
        {{ string_agg('ov.value', ', ', 'ov.value') }} as dd_suggested_use
    from dd_suggested_use_exploded as ex
    inner join option_value as ov
        on ov.option_id = ex.option_id
    group by ex.entity_id
)

select
    e.product_entity_id as entity_id,
    ip.manufacturer,
    ip.projectile,
    ip.unit_type,
    vp.rounds_package,
    vp.capacity,
    vp.material,
    ip.primary_category,
    ip.ddcaliber,
    ip.ddaction,
    ip.ddcondition,
    ip.ddgun_parts,
    ip.ddcolor,
    ocd.optic_coating,
    ip.ddweapons_platform,
    dsud.dd_suggested_use
from product_entity as e
left join int_pivot           as ip   on e.product_entity_id = ip.entity_id
left join varchar_pivot       as vp   on e.product_entity_id = vp.entity_id
left join optic_coating_data  as ocd  on e.product_entity_id = ocd.entity_id
left join dd_suggested_use_data as dsud on e.product_entity_id = dsud.entity_id
