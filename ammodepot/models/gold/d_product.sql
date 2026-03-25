with cte_final as (
    select
        fb.entity_id                                                                          as "Product ID",
        fb.sku                                                                                as SKU,
        attr.product_name                                                                     as "Product Name",
        attr.general_purpose                                                                  as "General Purpose",
        concat('{{ var("ammodepot_base_url") }}/', attr.url_key)                              as "Product URL",
        concat('{{ var("ammodepot_base_url") }}/media/catalog/product', attr.image)           as "Product Image URL",
        fb.vendor                                                                             as "Vendor",
        fb.discontinued                                                                       as "Discontinued",
        tax.parent_sku                                                                        as "Parent SKU",
        coalesce(tax.parent_sku, fb.sku)                                                      as GROUPED_SKU,
        attr.boxes_case                                                                       as "Boxes/Case",
        trim(attr.caliber)                                                                    as "Caliber",
        trim(attr.manufacturer_sku)                                                           as "Manufacturer SKU",
        attr.upc                                                                              as UPC,
        trim(eav.manufacturer)                                                                as "Manufacturer",
        trim(eav.projectile)                                                                  as "Projectile",
        trim(eav.unit_type)                                                                   as "Unit Type",
        eav.rounds_package                                                                    as "Rounds/Package",
        trim(fb.attribute_set_name)                                                           as "Attribute Set",
        tax.categories                                                                        as "Categories",
        trim(attr.gun_type)                                                                   as "Gun Type",
        trim(eav.ddcaliber)                                                                   as "DD Caliber",
        trim(eav.ddaction)                                                                    as "DD Gun Action",
        trim(eav.ddcondition)                                                                 as "DD Condition",
        trim(eav.ddgun_parts)                                                                 as "DD Gun Parts",
        trim(eav.capacity)                                                                    as "Capacity",
        trim(eav.material)                                                                    as "Material",
        trim(eav.primary_category)                                                            as "Primary Category",
        trim(eav.ddcolor)                                                                     as "DD Color",
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
    {# Product use-type classification: matches product attributes against
       parameterized lists in dbt_project.yml. Priority order:
       Hunting → Self-Defense → Tactical → Sporting → Collector → caliber fallback #}
    case
        when cf."Categories" ilike '%hunting%'
            or cf."General Purpose" ilike '%hunting%'
            or cf."Product Name" ilike '%hunting%'
            or cf."Projectile" in ({{ var('ammodepot_hunting_projectiles') }})
            or (cf."DD Caliber" in ({{ var('ammodepot_hunting_calibers') }})
                and cf."Projectile" not in ({{ var('ammodepot_non_hunting_projectiles') }}))
        then 'Hunting'

        when cf."Categories" ilike '%defense%'
            or cf."General Purpose" ilike '%defense%'
            or cf."Product Name" ilike '%defense%'
            or cf."Product Name" ilike '%personal%'
            or cf."Projectile" in ({{ var('ammodepot_defense_projectiles') }})
            or (cf."Projectile" = 'HP' and cf."DD Caliber" in ({{ var('ammodepot_defense_calibers') }}))
            or (cf."DD Caliber" in ({{ var('ammodepot_defense_calibers') }})
                and cf."Product Name" ilike '%carry%')
            or cf."Projectile" = '00 Buck'
            or cf."Projectile" like '%Buck%'
        then 'Self-Defense/Personal Protection'

        when cf."Categories" ilike '%tactical%'
            or cf."Categories" ilike '%law enforcement%'
            or cf."General Purpose" ilike '%tactical%'
            or cf."Product Name" ilike '%tactical%'
            or cf."Product Name" ilike '%duty%'
            or cf."Projectile" = 'SS109/Green Tip'
            or (cf."DD Caliber" in ({{ var('ammodepot_tactical_calibers') }})
                and cf."Projectile" in ({{ var('ammodepot_tactical_projectiles') }}))
            or cf."Product Name" ilike '%law enforcement%'
        then 'Tactical/Law Enforcement'

        when cf."Categories" ilike '%sport%'
            or cf."Categories" ilike '%target%'
            or cf."Categories" ilike '%competition%'
            or cf."General Purpose" ilike '%sport%'
            or cf."Product Name" ilike '%target%'
            or cf."Product Name" ilike '%competition%'
            or cf."Product Name" ilike '%match%'
            or (cf."Projectile" in ({{ var('ammodepot_sporting_projectiles') }})
                and not (cf."Product Name" ilike '%defense%' or cf."Product Name" ilike '%tactical%'))
            or cf."Projectile" in ({{ var('ammodepot_sporting_shot_types') }})
            or cf."Product Name" ilike '%practice%'
            or cf."Product Name" ilike '%range%'
            or cf."DD Caliber" = '22 LR'
        then 'Sporting/Target'

        when cf."Categories" ilike '%collector%'
            or cf."Product Name" ilike '%collector%'
            or cf."Product Name" ilike '%limited%'
            or cf."Product Name" ilike '%special edition%'
        then 'Collector/Specialty'

        {# Caliber-based fallback when no keyword/projectile match #}
        else case
            when cf."DD Caliber" in ({{ var('ammodepot_sporting_fallback_calibers') }})
                then 'Sporting/Target'
            when cf."DD Caliber" in ({{ var('ammodepot_hunting_fallback_calibers') }})
                then 'Hunting'
            when cf."DD Caliber" in ({{ var('ammodepot_defense_fallback_calibers') }})
                then 'Self-Defense/Personal Protection'
            when cf."DD Caliber" in ({{ var('ammodepot_tactical_fallback_calibers') }})
                then 'Tactical/Law Enforcement'
            when cf."DD Caliber" in ({{ var('ammodepot_shotgun_gauges') }})
                then case
                    when cf."Projectile" in ({{ var('ammodepot_shotgun_sporting_shot') }})
                        then 'Sporting/Target'
                    when cf."Projectile" in ({{ var('ammodepot_shotgun_defense_slug') }})
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
    end as USE_TYPE_CATEGORY

from cte_final as cf
