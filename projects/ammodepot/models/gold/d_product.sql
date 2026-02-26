with cte_final as (
    select
        fb.entity_id                                                                          as "Product ID",
        fb.sku                                                                                as SKU,
        attr.product_name                                                                     as "Product Name",
        attr.general_purpose                                                                  as "General Purpose",
        CONCAT('{{ var("ammodepot_base_url") }}/', attr.url_key)                              as "Product URL",
        CONCAT('{{ var("ammodepot_base_url") }}/media/catalog/product', attr.image)           as "Product Image URL",
        fb.vendor                                                                             as "Vendor",
        fb.discontinued                                                                       as "Discontinued",
        tax.parent_sku                                                                        as "Parent SKU",
        COALESCE(tax.parent_sku, fb.sku)                                                      as GROUPED_SKU,
        attr.boxes_case                                                                       as "Boxes/Case",
        attr.caliber                                                                          as "Caliber",
        attr.manufacturer_sku                                                                 as "Manufacturer SKU",
        attr.upc                                                                              as UPC,
        eav.manufacturer                                                                      as "Manufacturer",
        eav.projectile                                                                        as "Projectile",
        eav.unit_type                                                                         as "Unit Type",
        eav.rounds_package                                                                    as "Rounds/Package",
        fb.attribute_set_name                                                                 as "Attribute Set",
        tax.categories                                                                        as "Categories",
        attr.gun_type                                                                         as "Gun Type",
        eav.ddcaliber                                                                         as "DD Caliber",
        eav.ddaction                                                                          as "DD Gun Action",
        eav.ddcondition                                                                       as "DD Condition",
        eav.ddgun_parts                                                                       as "DD Gun Parts",
        eav.capacity                                                                          as "Capacity",
        eav.material                                                                          as "Material",
        eav.primary_category                                                                  as "Primary Category",
        eav.ddcolor                                                                           as "DD Color",
        eav.optic_coating                                                                     as "Optic Coating",
        eav.ddweapons_platform                                                                as "DD Weapons Platform",
        attr.thread_pattern                                                                   as "Thread Pattern",
        attr.thread_type                                                                      as "Thread Type",
        attr.model                                                                            as "Model",
        fb.convert                                                                            as CONVERT,
        fb.avgcost                                                                            as AVGCOST,
        fb.lastvendorcost                                                                     as LASTVENDORCOST,
        eav.dd_suggested_use                                                                  as "DD Suggested Use"
    from {{ ref('int_fishbowl_product_enrichment') }} as fb
    left join {{ ref('int_magento_product_attributes') }} as attr
        on fb.entity_id = attr.entity_id
    left join {{ ref('int_magento_product_eav_lookups') }} as eav
        on fb.entity_id = eav.entity_id
    left join {{ ref('int_magento_product_taxonomy') }} as tax
        on fb.entity_id = tax.entity_id
)

select
    cf."Product ID",
    cf.SKU,
    cf."Product Name",
    cf."General Purpose",
    cf."Product URL",
    cf."Product Image URL",
    cf."Vendor",
    cf."Discontinued",
    cf."Parent SKU",
    cf.GROUPED_SKU,
    cf."Boxes/Case",
    cf."Caliber",
    cf."Manufacturer SKU",
    cf.UPC,
    cf."Manufacturer",
    cf."Projectile",
    cf."Unit Type",
    cf."Rounds/Package",
    cf."Attribute Set",
    cf."Categories",
    cf."Gun Type",
    cf."DD Caliber",
    cf."DD Gun Action",
    cf."DD Condition",
    cf."DD Gun Parts",
    cf."Capacity",
    cf."Material",
    cf."Primary Category",
    cf."DD Color",
    cf."Optic Coating",
    cf."DD Weapons Platform",
    cf."Thread Pattern",
    cf."Thread Type",
    cf."Model",
    cf.CONVERT,
    cf.AVGCOST,
    cf.LASTVENDORCOST,
    cf."DD Suggested Use",
    -- Use Type Category Logic
    case
        when cf."Categories" ilike '%hunting%'
            or cf."General Purpose" ilike '%hunting%'
            or cf."Product Name" ilike '%hunting%'
            or cf."Projectile" in ('SP', 'JSP', 'TSX', 'TTSX', 'Partition', 'AccuBond', 'Nosler', 'SST', 'InterLock')
            or (cf."DD Caliber" in (
                '.30-06', '.308 Win', '.270 Win', '.243 Win', '7mm Rem Mag', '6.5 Creedmoor',
                '30-06 Springfield', '308/7.62', '270 Win', '243 Win', '7mm Rem Mag', '6.5 Creedmoor',
                '300 Win Mag', '7mm-08'
            ) and cf."Projectile" not in ('FMJ', 'TMJ', 'RN', 'Frangible'))
        then 'Hunting'

        when cf."Categories" ilike '%defense%'
            or cf."General Purpose" ilike '%defense%'
            or cf."Product Name" ilike '%defense%'
            or cf."Product Name" ilike '%personal%'
            or cf."Projectile" in ('JHP', 'XTP', 'Gold Dot', 'HST', 'Critical Defense', 'Critical Duty')
            or (cf."Projectile" = 'HP' and cf."DD Caliber" in (
                '9mm', '.45 ACP', '.380 Auto', '.38 Special', '.40 S&W', '.357 Mag',
                '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag', '10mm', '44 Mag'
            ))
            or (cf."DD Caliber" in (
                '9mm', '.45 ACP', '.380 Auto', '.38 Special', '.40 S&W', '.357 Mag',
                '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag', '10mm', '44 Mag'
            ) and cf."Product Name" ilike '%carry%')
            or cf."Projectile" = '00 Buck'
            or cf."Projectile" like '%Buck%'
        then 'Self-Defense/Personal Protection'

        when cf."Categories" ilike '%tactical%'
            or cf."Categories" ilike '%law enforcement%'
            or cf."General Purpose" ilike '%tactical%'
            or cf."Product Name" ilike '%tactical%'
            or cf."Product Name" ilike '%duty%'
            or cf."Projectile" = 'SS109/Green Tip'
            or (cf."DD Caliber" in ('5.56 NATO', '223/5.56', '300 Blackout')
                and cf."Projectile" in ('HP', 'OTM', 'BTHP'))
            or cf."Product Name" ilike '%law enforcement%'
        then 'Tactical/Law Enforcement'

        when cf."Categories" ilike '%sport%'
            or cf."Categories" ilike '%target%'
            or cf."Categories" ilike '%competition%'
            or cf."General Purpose" ilike '%sport%'
            or cf."Product Name" ilike '%target%'
            or cf."Product Name" ilike '%competition%'
            or cf."Product Name" ilike '%match%'
            or (cf."Projectile" in ('FMJ', 'TMJ', 'FMJBT', 'LRN', 'LFN')
                and not (cf."Product Name" ilike '%defense%' or cf."Product Name" ilike '%tactical%'))
            or cf."Projectile" in ('7.5 Shot', '8 Shot', '9 Shot', 'Clay & Target', 'Game & Target')
            or cf."Product Name" ilike '%practice%'
            or cf."Product Name" ilike '%range%'
            or cf."DD Caliber" = '22 LR'
        then 'Sporting/Target'

        when cf."Categories" ilike '%collector%'
            or cf."Product Name" ilike '%collector%'
            or cf."Product Name" ilike '%limited%'
            or cf."Product Name" ilike '%special edition%'
        then 'Collector/Specialty'

        else case
            when cf."DD Caliber" in ('22 LR', '22 Mag/WMR', '17 HMR', '22-250', '6mm Creedmoor')
                then 'Sporting/Target'
            when cf."DD Caliber" in (
                '30-06 Springfield', '308/7.62', '270 Win', '243 Win', '300 Win Mag',
                '7mm Rem Mag', '6.5 Creedmoor', '7mm-08', '25-06', '280 Rem', '35 Rem'
            )
                then 'Hunting'
            when cf."DD Caliber" in (
                '9mm', '45 ACP', '380 ACP', '38 Special', '40 S&W', '357 Mag',
                '10mm', '44 Mag', '45 LC'
            )
                then 'Self-Defense/Personal Protection'
            when cf."DD Caliber" in ('223/5.56', '300 Blackout', '308 Win Match', '338 Lapua')
                then 'Tactical/Law Enforcement'
            when cf."DD Caliber" in ('12 Gauge', '20 Gauge', '410 Bore', '28 Gauge')
                then case
                    when cf."Projectile" in ('7.5 Shot', '8 Shot', '9 Shot', '7 Shot', '6 Shot', '5 Shot', '4 Shot')
                        then 'Sporting/Target'
                    when cf."Projectile" in ('00 Buck', 'Slug', 'OO Buck', '000 Buck', '4 Buck', 'Buckshot', '1 Buck', '2 Buck', '3 Buck')
                        then 'Self-Defense/Personal Protection'
                    else 'Sporting/Target'
                end
            when cf."Projectile" in ('FMJ', 'TMJ', 'Ball', 'LRN', 'LFN')
                then 'Sporting/Target'
            when cf."Projectile" in ('JHP', 'HP', 'XTP')
                then 'Self-Defense/Personal Protection'
            when cf."Projectile" in ('SP', 'JSP', 'BTSP')
                then 'Hunting'
            else 'Unclassified'
        end
    end as use_type_category

from cte_final as cf
