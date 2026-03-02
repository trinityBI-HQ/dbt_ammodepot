with attribute_id_cte as (
    select
        attribute_id,
        attribute_code
    from {{ ref('magento_eav_attribute') }}
    where attribute_code = 'name'
),

category_data as (
    select
        ccp.product_id,
        listagg(ccv.value, ' > ') within group (order by ccv.value) as categories
    from {{ ref('magento_catalog_category_product') }} as ccp
    inner join {{ ref('magento_catalog_category_entity_varchar') }} as ccv
        on ccp.category_id = ccv.entity_id
    inner join attribute_id_cte as ac
        on ccv.attribute_id = ac.attribute_id
        and ac.attribute_code = 'name'
    group by ccp.product_id
),

parent_sku_data as (
    select
        sl.product_id,
        parent.sku as parent_sku
    from {{ ref('magento_catalog_product_super_link') }} as sl
    inner join {{ ref('magento_catalog_product_entity') }} as parent
        on sl.parent_id = parent.product_entity_id
)

select
    e.product_entity_id as entity_id,
    cd.categories,
    psd.parent_sku
from {{ ref('magento_catalog_product_entity') }} as e
left join category_data as cd
    on e.product_entity_id = cd.product_id
left join parent_sku_data as psd
    on e.product_entity_id = psd.product_id
