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
),
vendorpartscost AS (
    select
        datelastmodified,
        partid,
        lastcost,
        ROW_NUMBER() OVER (PARTITION BY partid ORDER BY datelastmodified DESC) AS rn
    FROM
        {{ ref('fishbowl_vendor_parts') }}
),

vendorlast AS ( 
    SELECT
        datelastmodified,
        partid,
        lastcost
    FROM
        vendorpartscost
    WHERE
        rn = 1
),

Fishbowl_Conversion AS (
    SELECT 
        pr.product_number, 
        AVG(uom.multiply_factor) AS CONVERT,
        AVG(pc.average_cost) AS AVGCOST,
        AVG(vp.lastcost) AS LASTVENDORCOST
    FROM
        {{ ref('fishbowl_product') }} pr
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uom ON pr.uom_id = uom.from_uom_id AND uom.to_uom_id = 1
    LEFT JOIN
        {{ ref('fishbowl_partcost') }} pc ON pr.part_id = pc.part_id
    LEFT JOIN
        vendorlast vp ON pr.part_id = vp.partid

    group by
     pr.product_number
)

SELECT
    e.product_entity_id                               AS "Product ID",
    e.sku                                             AS SKU,
    MAX(CASE WHEN va.attribute_code = 'name'            THEN va.value END) AS "Product Name",
    MAX(CASE WHEN va.attribute_code = 'suggested_use'   THEN va.value END) AS "General Purpose",
    MAX(CASE WHEN va.attribute_code = 'url_key'         THEN CONCAT('https://www.ammunitiondepot.com/', va.value) END) AS "Product URL",
    MAX(CASE WHEN va.attribute_code = 'image'           THEN CONCAT('https://www.ammunitiondepot.com/media/catalog/product', va.value) END) AS "Product Image URL",
    vd.vendor                                         AS "Vendor",
    dd.discontinued                                   AS "Discontinued",
    psd.parent_sku                                    AS "Parent SKU",
    COALESCE(psd.parent_sku, e.sku)                   AS GROUPED_SKU,
    MAX(CASE WHEN va.attribute_code = 'boxes_case'      THEN va.value END) AS "Boxes/Case",
    MAX(CASE WHEN va.attribute_code = 'caliber'         THEN va.value END) AS "Caliber",
    MAX(CASE WHEN va.attribute_code = 'manufacturer_sku' THEN va.value END) AS "Manufacturer SKU",
    MAX(CASE WHEN va.attribute_code = 'upc'             THEN va.value END) AS UPC,
    MAX(md.manufacturer)                              AS "Manufacturer",
    MAX(pd.projectile)                                AS "Projectile",
    MAX(utd.unit_type)                                AS "Unit Type",
    MAX(rpd.rounds_package)                           AS "Rounds/Package",
    MAX(asd.attribute_set_name)                       AS "Attribute Set",
    cd.categories                                     AS "Categories",
    MAX(CASE WHEN va.attribute_code = 'gun_type'       THEN va.value END) AS "Gun Type",
    MAX(ddc.ddcaliber)                                AS "DD Caliber",
    MAX(ddact.ddaction)                               AS "DD Gun Action",
    MAX(ddcond.ddcondition)                           AS "DD Condition",
    MAX(ddgp.ddgun_parts)                             AS "DD Gun Parts",
    MAX(capacity.capacity)                            AS "Capacity",
    MAX(material.material)                            AS "Material",
    MAX(pc.primary_category)                          AS "Primary Category",
    MAX(dc.ddcolor)                                   AS "DD Color",
    MAX(oc.optic_coating)                             AS "Optic Coating",
    MAX(dwp.ddweapons_platform)                       AS "DD Weapons Platform",
    MAX(CASE WHEN va.attribute_code = 'thread_pattern' THEN va.value END) AS "Thread Pattern",
    MAX(CASE WHEN va.attribute_code = 'thread_type'    THEN va.value END) AS "Thread Type",
    MAX(CASE WHEN va.attribute_code = 'model'          THEN va.value END) AS "Model",
    Coalesce(MAX(fbc.CONVERT),1) AS CONVERT,
    MAX(fbc.avgcost) AS AVGCOST,
    MAX(fbc.LASTVENDORCOST) AS LASTVENDORCOST
FROM {{ ref('magento_catalog_product_entity') }} e
LEFT JOIN varchar_attributes            va   ON e.product_entity_id = va.entity_id
LEFT JOIN int_attributes                ia   ON e.product_entity_id = ia.entity_id
LEFT JOIN decimal_attributes            da   ON e.product_entity_id = da.entity_id
LEFT JOIN text_attributes               ta   ON e.product_entity_id = ta.entity_id
LEFT JOIN category_data                 cd   ON e.product_entity_id = cd.product_id
LEFT JOIN vendor_data                   vd   ON e.product_entity_id = vd.entity_id
LEFT JOIN parent_sku_data               psd  ON e.product_entity_id = psd.product_id
LEFT JOIN discontinued_data             dd   ON e.product_entity_id = dd.product_entity_id
LEFT JOIN manufacturer_data             md   ON e.product_entity_id = md.entity_id
LEFT JOIN projectile_data               pd   ON e.product_entity_id = pd.entity_id
LEFT JOIN unit_type_data                utd  ON e.product_entity_id = utd.entity_id
LEFT JOIN rounds_package_data           rpd  ON e.product_entity_id = rpd.entity_id
LEFT JOIN capacity_data                 capacity ON e.product_entity_id = capacity.entity_id
LEFT JOIN material_data                 material ON e.product_entity_id = material.entity_id
LEFT JOIN attribute_set_data            asd  ON e.product_entity_id = asd.product_entity_id
LEFT JOIN primary_category_data         pc   ON e.product_entity_id = pc.entity_id
LEFT JOIN ddcaliber_data                ddc  ON e.product_entity_id = ddc.entity_id
LEFT JOIN ddaction_data                 ddact ON e.product_entity_id = ddact.entity_id
LEFT JOIN ddcondition_data              ddcond ON e.product_entity_id = ddcond.entity_id
LEFT JOIN ddgun_parts_data              ddgp ON e.product_entity_id = ddgp.entity_id
LEFT JOIN ddcolor_data                  dc   ON e.product_entity_id = dc.entity_id
LEFT JOIN optic_coating_data            oc   ON e.product_entity_id = oc.entity_id
LEFT JOIN ddweapons_platform_data       dwp  ON e.product_entity_id = dwp.entity_id
LEFT JOIN Fishbowl_Conversion           fbc  ON e.sku = fbc.product_number
GROUP BY
    e.product_entity_id,
    e.sku,
    cd.categories,
    vd.vendor,
    dd.discontinued,
    psd.parent_sku
