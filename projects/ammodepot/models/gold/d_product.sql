{{
    config(
        materialized = 'table',
        schema       = 'gold'
    )
}}

WITH attribute_id_cte AS (
    SELECT 
        attribute_id, 
        attribute_code
    FROM {{ ref('magento_eav_attribute') }}
    WHERE attribute_code IN (
        'name', 'url_key', 'manufacturer_sku', 'upc', 'image', 'cost', 'price',
        'status', 'visibility', 'weight', 'manufacturer', 'attribute_set_name',
        'brand_type', 'grain_weight', 'unit_type', 'projectile', 'caliber',
        'boxes_case', 'rounds_package', 'suggested_use', 'gun_type', 'ddcaliber',
        'capacity', 'ddaction', 'ddcondition', 'material', 'ddgun_parts',
        'primary_category', 'ddcolor', 'optic_coating', 'ddweapons_platform',
        'thread_pattern', 'thread_type', 'model', 'dd_suggested_use'
    )
),

test1 AS (
    SELECT *
    FROM {{ ref('magento_catalog_product_entity_int') }}
),

varchar_attributes AS (
    SELECT
        cpv.entity_id,
        ac.attribute_code,
        cpv.value
    FROM {{ ref('magento_catalog_product_entity_varchar') }} cpv
    JOIN attribute_id_cte ac
        ON cpv.attribute_id = ac.attribute_id
    WHERE cpv.store_id = 0
),

text_attributes AS (
    SELECT
        cpt.entity_id,
        ac.attribute_code,
        cpt.value
    FROM {{ ref('magento_catalog_product_entity_text') }} cpt
    JOIN attribute_id_cte ac
        ON cpt.attribute_id = ac.attribute_id
    WHERE cpt.store_id = 0
),

int_attributes AS (
    SELECT
        cpi.entity_id,
        ac.attribute_code,
        cpi.value
    FROM test1 cpi
    JOIN attribute_id_cte ac
        ON cpi.attribute_id = ac.attribute_id
    WHERE cpi.store_id = 0
),

decimal_attributes AS (
    SELECT
        cpd.entity_id,
        ac.attribute_code,
        cpd.value
    FROM {{ ref('magento_catalog_product_entity_decimal') }} cpd
    JOIN attribute_id_cte ac
        ON cpd.attribute_id = ac.attribute_id
    WHERE cpd.store_id = 0
),

category_data AS (
    SELECT
        ccp.product_id,
        LISTAGG(ccv.value, ' > ') WITHIN GROUP (ORDER BY ccv.value) AS categories
    FROM {{ ref('magento_catalog_category_product') }} ccp
    JOIN {{ ref('magento_catalog_category_entity_varchar') }} ccv
        ON ccp.category_id = ccv.entity_id
    JOIN attribute_id_cte ac
        ON ccv.attribute_id = ac.attribute_id
        AND ac.attribute_code = 'name'
    GROUP BY ccp.product_id
),
dd_suggested_use_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS dd_suggested_use
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 682 
        AND cpi.store_id = 0
),
parent_sku_data AS (
    SELECT
        sl.product_id,
        parent.sku AS parent_sku
    FROM {{ ref('magento_catalog_product_super_link') }} sl
    JOIN {{ ref('magento_catalog_product_entity') }} parent
        ON sl.parent_id = parent.product_entity_id
),

discontinued_data AS (
    SELECT
        product_entity_id,
        CASE 
            WHEN attribute_set_id = 50 THEN 'Yes' 
            ELSE 'No' 
        END AS discontinued
    FROM {{ ref('magento_catalog_product_entity') }}
),

manufacturer_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS manufacturer
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 677
        AND cpi.store_id = 0
),

projectile_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS projectile
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 681
        AND cpi.store_id = 0
),

unit_type_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS unit_type
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 649
        AND cpi.store_id = 0
),

ddcaliber_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddcaliber
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 678
        AND cpi.store_id = 0
),

ddaction_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddaction
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 718
        AND cpi.store_id = 0
),

ddcondition_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddcondition
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 676
        AND cpi.store_id = 0
),

ddgun_parts_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddgun_parts
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 817
        AND cpi.store_id = 0
),

rounds_package_data AS (
    SELECT
        cpv.entity_id,
        cpv.value AS rounds_package
    FROM {{ ref('magento_catalog_product_entity_varchar') }} cpv
    WHERE cpv.attribute_id = 152
        AND cpv.store_id = 0
),

capacity_data AS (
    SELECT
        cpv.entity_id,
        cpv.value AS capacity
    FROM {{ ref('magento_catalog_product_entity_varchar') }} cpv
    WHERE cpv.attribute_id = 165
        AND cpv.store_id = 0
),

vendor_data AS (
    SELECT
        cpei.entity_id,
        ev.value AS vendor
    FROM test1 cpei
    JOIN {{ ref('magento_eav_attribute_option_value') }} ev
        ON cpei.value = ev.option_id
    WHERE cpei.attribute_id = 145
),

material_data AS (
    SELECT
        cpv.entity_id,
        cpv.value AS material
    FROM {{ ref('magento_catalog_product_entity_varchar') }} cpv
    WHERE cpv.attribute_id = 188
        AND cpv.store_id = 0
),

attribute_set_data AS (
    SELECT
        cpe.product_entity_id,
        eas.attribute_set_name
    FROM {{ ref('magento_catalog_product_entity') }} cpe
    JOIN {{ ref('magento_eav_attribute_set') }} eas
        ON cpe.attribute_set_id = eas.attribute_set_id
),

primary_category_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS primary_category
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 878
        AND cpi.store_id = 0
),

ddcolor_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddcolor
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 685
        AND cpi.store_id = 0
),

optic_coating_data AS (
    SELECT
        cpt.entity_id,
        cpt.value AS optic_coating
    FROM {{ ref('magento_catalog_product_entity_text') }} cpt
    JOIN attribute_id_cte ac
        ON cpt.attribute_id = ac.attribute_id
    WHERE ac.attribute_code = 'optic_coating'
        AND cpt.store_id = 0
),

ddweapons_platform_data AS (
    SELECT
        cpi.entity_id,
        eov.value AS ddweapons_platform
    FROM test1 cpi
    JOIN {{ ref('magento_eav_attribute_option_value') }} eov
        ON cpi.value = eov.option_id
        AND eov.store_id = 0
    WHERE cpi.attribute_id = 756
        AND cpi.store_id = 0
),

vendorpartscost AS (
    SELECT
        datelastmodified,
        partid,
        lastcost,
        ROW_NUMBER() OVER (PARTITION BY partid ORDER BY datelastmodified DESC) AS rn
    FROM {{ ref('fishbowl_vendor_parts') }}
),

vendorlast AS ( 
    SELECT
        datelastmodified,
        partid,
        lastcost
    FROM vendorpartscost
    WHERE rn = 1
),

fishbowl_conversion AS (
    SELECT 
        pr.product_number, 
        AVG(uom.multiply_factor) AS convert,
        AVG(pc.average_cost) AS avgcost,
        AVG(vp.lastcost) AS lastvendorcost
    FROM {{ ref('fishbowl_product') }} pr
    LEFT JOIN {{ ref('fishbowl_uomconversion') }} uom 
        ON pr.uom_id = uom.from_uom_id 
        AND uom.to_uom_id = 1
    LEFT JOIN {{ ref('fishbowl_partcost') }} pc 
        ON pr.part_id = pc.part_id
    LEFT JOIN vendorlast vp 
        ON pr.part_id = vp.partid
    GROUP BY pr.product_number
),

cte_final AS (
    SELECT
        e.product_entity_id                               AS "Product ID",
        e.sku                                             AS "SKU",
        MAX(CASE WHEN va.attribute_code = 'name'            THEN va.value END) AS "Product Name",
        MAX(CASE WHEN va.attribute_code = 'suggested_use'   THEN va.value END) AS "General Purpose",
        MAX(CASE WHEN va.attribute_code = 'url_key'         THEN CONCAT('https://www.ammunitiondepot.com/', va.value) END) AS "Product URL",
        MAX(CASE WHEN va.attribute_code = 'image'           THEN CONCAT('https://www.ammunitiondepot.com/media/catalog/product', va.value) END) AS "Product Image URL",
        vd.vendor                                         AS "Vendor",
        dd.discontinued                                   AS "Discontinued",
        psd.parent_sku                                    AS "Parent SKU",
        COALESCE(psd.parent_sku, e.sku)                   AS "GROUPED_SKU",
        MAX(CASE WHEN va.attribute_code = 'boxes_case'      THEN va.value END) AS "Boxes/Case",
        MAX(CASE WHEN va.attribute_code = 'caliber'         THEN va.value END) AS "Caliber",
        MAX(CASE WHEN va.attribute_code = 'manufacturer_sku' THEN va.value END) AS "Manufacturer SKU",
        MAX(CASE WHEN va.attribute_code = 'upc'             THEN va.value END) AS "UPC",
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
        COALESCE(MAX(fbc.convert), 1)                     AS "CONVERT",
        MAX(fbc.avgcost)                                  AS "AVGCOST",
        MAX(fbc.lastvendorcost)                           AS "LASTVENDORCOST",
        MAX(dsud.dd_suggested_use)                        AS "DD Suggested Use"
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
    LEFT JOIN fishbowl_conversion           fbc  ON e.sku = fbc.product_number
    LEFT JOIN dd_suggested_use_data         dsud ON e.product_entity_id = dsud.entity_id
    GROUP BY
        e.product_entity_id,
        e.sku,
        cd.categories,
        vd.vendor,
        dd.discontinued,
        psd.parent_sku
)

SELECT 
    cf.*,
    -- Use Type Category Logic
    CASE 
        WHEN cf."Categories" ILIKE '%hunting%' 
            OR cf."General Purpose" ILIKE '%hunting%' 
            OR cf."Product Name" ILIKE '%hunting%' 
            OR cf."Projectile" IN ('SP', 'JSP', 'TSX', 'TTSX', 'Partition', 'AccuBond', 'Nosler', 'SST', 'InterLock') 
            OR (cf."DD Caliber" IN (
                '.30-06', '.308 Win', '.270 Win', '.243 Win', '7mm Rem Mag', '6.5 Creedmoor', 
                '30-06 Springfield', '308/7.62', '270 Win', '243 Win', '7mm Rem Mag', '6.5 Creedmoor',
                '300 Win Mag', '7mm-08'
            ) AND cf."Projectile" NOT IN ('FMJ', 'TMJ', 'RN', 'Frangible')) 
        THEN 'Hunting'

        WHEN cf."Categories" ILIKE '%defense%' 
            OR cf."General Purpose" ILIKE '%defense%' 
            OR cf."Product Name" ILIKE '%defense%' 
            OR cf."Product Name" ILIKE '%personal%' 
            OR cf."Projectile" IN ('JHP', 'XTP', 'Gold Dot', 'HST', 'Critical Defense', 'Critical Duty') 
            OR (cf."Projectile" = 'HP' AND cf."DD Caliber" IN (
                '9mm', '.45 ACP', '.380 Auto', '.38 Special', '.40 S&W', '.357 Mag',
                '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag', '10mm', '44 Mag'
            )) 
            OR (cf."DD Caliber" IN (
                '9mm', '.45 ACP', '.380 Auto', '.38 Special', '.40 S&W', '.357 Mag',
                '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag', '10mm', '44 Mag'
            ) AND cf."Product Name" ILIKE '%carry%') 
            OR cf."Projectile" = '00 Buck' 
            OR cf."Projectile" LIKE '%Buck%' 
        THEN 'Self-Defense/Personal Protection'

        WHEN cf."Categories" ILIKE '%tactical%' 
            OR cf."Categories" ILIKE '%law enforcement%' 
            OR cf."General Purpose" ILIKE '%tactical%' 
            OR cf."Product Name" ILIKE '%tactical%' 
            OR cf."Product Name" ILIKE '%duty%' 
            OR cf."Projectile" = 'SS109/Green Tip' 
            OR (cf."DD Caliber" IN ('5.56 NATO', '223/5.56', '300 Blackout') 
                AND cf."Projectile" IN ('HP', 'OTM', 'BTHP')) 
            OR cf."Product Name" ILIKE '%law enforcement%' 
        THEN 'Tactical/Law Enforcement'

        WHEN cf."Categories" ILIKE '%sport%' 
            OR cf."Categories" ILIKE '%target%' 
            OR cf."Categories" ILIKE '%competition%' 
            OR cf."General Purpose" ILIKE '%sport%' 
            OR cf."Product Name" ILIKE '%target%' 
            OR cf."Product Name" ILIKE '%competition%' 
            OR cf."Product Name" ILIKE '%match%' 
            OR (cf."Projectile" IN ('FMJ', 'TMJ', 'FMJBT', 'LRN', 'LFN') 
                AND NOT (cf."Product Name" ILIKE '%defense%' OR cf."Product Name" ILIKE '%tactical%')) 
            OR cf."Projectile" IN ('7.5 Shot', '8 Shot', '9 Shot', 'Clay & Target', 'Game & Target') 
            OR cf."Product Name" ILIKE '%practice%' 
            OR cf."Product Name" ILIKE '%range%' 
            OR cf."DD Caliber" = '22 LR' 
        THEN 'Sporting/Target'

        WHEN cf."Categories" ILIKE '%collector%' 
            OR cf."Product Name" ILIKE '%collector%' 
            OR cf."Product Name" ILIKE '%limited%' 
            OR cf."Product Name" ILIKE '%special edition%' 
        THEN 'Collector/Specialty'

        ELSE CASE
            WHEN cf."DD Caliber" IN ('22 LR', '22 Mag/WMR', '17 HMR', '22-250', '6mm Creedmoor') 
                THEN 'Sporting/Target'
            WHEN cf."DD Caliber" IN (
                '30-06 Springfield', '308/7.62', '270 Win', '243 Win', '300 Win Mag',
                '7mm Rem Mag', '6.5 Creedmoor', '7mm-08', '25-06', '280 Rem', '35 Rem'
            ) 
                THEN 'Hunting'
            WHEN cf."DD Caliber" IN (
                '9mm', '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag',
                '10mm', '44 Mag', '45 LC'
            ) 
                THEN 'Self-Defense/Personal Protection'
            WHEN cf."DD Caliber" IN ('223/5.56', '300 Blackout', '308 Win Match', '338 Lapua') 
                THEN 'Tactical/Law Enforcement'
            WHEN cf."DD Caliber" IN ('12 Gauge', '20 Gauge', '410 Bore', '28 Gauge') 
                THEN CASE
                    WHEN cf."Projectile" IN ('7.5 Shot', '8 Shot', '9 Shot', '7 Shot', '6 Shot', '5 Shot', '4 Shot') 
                        THEN 'Sporting/Target'
                    WHEN cf."Projectile" IN ('00 Buck', 'Slug', 'OO Buck', '000 Buck', '4 Buck', 'Buckshot', '1 Buck', '2 Buck', '3 Buck') 
                        THEN 'Self-Defense/Personal Protection'
                    ELSE 'Sporting/Target'
                END
            WHEN cf."Projectile" IN ('FMJ', 'TMJ', 'Ball', 'LRN', 'LFN') 
                THEN 'Sporting/Target'
            WHEN cf."Projectile" IN ('JHP', 'HP', 'XTP') 
                THEN 'Self-Defense/Personal Protection'
            WHEN cf."Projectile" IN ('SP', 'JSP', 'BTSP') 
                THEN 'Hunting'
            ELSE 'Unclassified'
        END
    END AS use_type_category

FROM cte_final cf
