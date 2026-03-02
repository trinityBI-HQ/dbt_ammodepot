with magento_identities as (
    select
        nullif(
          {{ json_extract_text('a.custom_fields', ['Magento Order Identity 1']) }},
          ''
        ) as magento_order_item_identity,
        a.sales_order_id as code
    from {{ ref('fishbowl_so') }} as a
    where {{ json_extract_text('a.custom_fields', ['Magento Order Identity 1']) }} is not null
),

conversion_soitem as (
    select
        z.so_item_id as idfb,
        coalesce(
            nullif({{ json_extract_text('z.custom_fields', ['25', 'value']) }}, ''),
            p.channel_id
        ) as mgntid
    from {{ ref('fishbowl_soitem') }} as z
    left join {{ ref('fishbowl_plugininfo') }} as p
        on p.record_id = z.so_item_id
        and p.related_table_name = 'SOItem'
),

conversion_product as (
    select
        f.record_id  as produtofish,
        f.channel_id as produto_magento
    from {{ ref('fishbowl_plugininfo') }} as f
    where f.related_table_name = 'Product'
),

cost_test as (
    select
        z.total_cost                  as cost,
        m.magento_order_item_identity as magento_order,
        t.produto_magento             as id_produto_magento,
        child.mgntid                  as id_magento,
        z.so_item_id                  as id_soitem,
        z.sales_order_id              as order_fishbowl_id
    from {{ ref('fishbowl_soitem') }} as z
    left join conversion_soitem   as child on z.so_item_id     = child.idfb
    left join conversion_product  as t     on z.product_id     = t.produtofish
    left join magento_identities  as m     on z.sales_order_id = m.code
),

cost_aggregation as (
    select
        id_magento            as id,
        count(*)              as count_of_id_magento,
        max(order_fishbowl_id) as order_fb
    from cost_test
    group by id_magento
),

uom_to_base as (
    select
        from_uom_id      as fromuomid,
        multiply_factor  as multiply,
        to_uom_id        as touomid
    from {{ ref('fishbowl_uomconversion') }}
    where to_uom_id = {{ var('ammodepot_base_uom_id') }}
),

product_avg_cost as (
    select
        p.product_id                                  as id_produto,
        u.multiply                                    as conversion,
        coalesce(c.average_cost * u.multiply, c.average_cost)
                                                     as averagecost,
        c.average_cost                                as costnoconversion
    from {{ ref('fishbowl_product') }}     as p
    left join {{ ref('fishbowl_partcost') }} as c on p.part_id  = c.part_id
    left join uom_to_base                       as u on p.uom_id  = u.fromuomid
),

object_kit as (
    select
        object1_record_id    as recordid1,
        object2_record_id    as recordid2,
        relationship_type_id as typeid
    from {{ ref('fishbowl_objecttoobject') }}
    where relationship_type_id = {{ var('ammodepot_kit_relationship_type_id') }}
),

kit_cost_aggregation as (
    select
        coalesce(
    nullif(sum(cast(s.total_cost as decimal(38,9))),0),
    sum(cast(s.quantity_ordered as decimal(38,9)) * cast(a.averagecost as decimal(38,9)))
) as cost,
        k.recordid2             as kitid,
        sum(a.averagecost)      as costprocessing,
        max(s.quantity_ordered) as maxqtytest
    from {{ ref('fishbowl_soitem') }} as s
    left join product_avg_cost          as a on s.product_id = a.id_produto
    left join object_kit                as k on s.so_item_id  = k.recordid1
    where s.item_type_id = {{ var('ammodepot_sale_item_type_id') }}
      and s.product_description not ilike '%POLLYAMOBAG%'
    group by k.recordid2
),

cost_fishbowl_base as (
    select
        case when s.total_cost = 0 then k.cost else s.total_cost end as cost,
        m.magento_order_item_identity                             as magento_order,
        pr.produto_magento                                        as id_produto_magento,
        child.mgntid                                              as id_magento,
        s.so_item_id,
        s.sales_order_id,
        ca.count_of_id_magento,
        s.product_id                                              as id_produto_fishbowl,
        p.is_kit                                                  as bundle,
        coalesce(k.costprocessing, a.averagecost)                 as averageweightedcost,
        s.scheduled_fulfillment_date                              as scheduled_fulfillment_date,
        s.quantity_fulfilled                                      as qty
    from {{ ref('fishbowl_soitem') }} as s
    left join conversion_soitem         as child on s.so_item_id       = child.idfb
    left join product_avg_cost          as a     on s.product_id       = a.id_produto
    left join conversion_product        as pr    on s.product_id       = pr.produtofish
    left join magento_identities        as m     on s.sales_order_id   = m.code
    left join cost_aggregation          as ca    on child.mgntid        = ca.id
    left join {{ ref('fishbowl_product') }}      as p     on s.product_id       = p.product_id
    left join kit_cost_aggregation      as k     on s.so_item_id       = k.kitid
),

last_day_cost_fishbowl as (
    select
        id_produto_fishbowl             as product_id,
        max(scheduled_fulfillment_date) as last_scheduled_date
    from cost_fishbowl_base
    where cost is not null and cost > 0
    group by id_produto_fishbowl
),

filtered_cost_fishbowl as (
    select
        f.id_produto_fishbowl         as product_id,
        avg(f.cost / nullif(f.qty,0)) as cost
    from cost_fishbowl_base as f
    inner join last_day_cost_fishbowl     as ld
      on f.id_produto_fishbowl         = ld.product_id
     and f.scheduled_fulfillment_date = ld.last_scheduled_date
    where f.cost is not null and f.cost > 0
    group by f.id_produto_fishbowl
),

cost_fishbowl_final as (
    select
        coalesce(nullif(b.total_cost,0), nullif(k.cost,0)) as cost,
        b.total_cost as totalcost,
        k.cost                            as costbundle,
        m.magento_order_item_identity     as magento_order,
        fc.cost                           as costfiltered,
        pr.produto_magento                as id_produto_magento,
        child.mgntid                      as id_magento,
        b.so_item_id,
        b.sales_order_id,
        ca.count_of_id_magento,
        b.product_id                                              as id_produto_fishbowl,
        p.is_kit                                                  as bundle,
        coalesce(k.costprocessing, a.averagecost)                 as averageweightedcost,
        b.scheduled_fulfillment_date                              as scheduled_fulfillment_date,
        b.quantity_fulfilled                                      as qty
    from {{ ref('fishbowl_soitem') }}      as b
    left join conversion_soitem         as child on b.so_item_id       = child.idfb
    left join product_avg_cost          as a     on b.product_id       = a.id_produto
    left join conversion_product        as pr    on b.product_id       = pr.produtofish
    left join magento_identities        as m     on b.sales_order_id   = m.code
    left join cost_aggregation          as ca    on child.mgntid       = ca.id
    left join {{ ref('fishbowl_product') }}      as p     on b.product_id       = p.product_id
    left join kit_cost_aggregation as k on b.so_item_id        = k.kitid
    left join filtered_cost_fishbowl as fc on b.product_id = fc.product_id

),

cost_unique_magento_id as (
    select f.*
    from cost_fishbowl_final   as f
    inner join cost_aggregation      as ca on f.id_magento      = ca.id
    where ca.count_of_id_magento = 1
),

cost_duplicate_magento_id_product as (
    select
        avg(f.cost)                as cost,
        f.id_magento               as id_magento,
        avg(f.averageweightedcost) as averageweightedcost,
        f.id_produto_magento       as id_produto_magento
    from cost_fishbowl_final    as f
    inner join cost_aggregation       as ca on f.id_magento      = ca.id
    where ca.count_of_id_magento > 1
    group by f.id_magento, f.id_produto_magento
),

cost_duplicate_magento_id_avg as (
    select
        avg(d.cost)                as cost,
        avg(d.averageweightedcost) as averageweightedcost,
        d.id_magento
    from cost_duplicate_magento_id_product as d
    inner join {{ ref('magento_sales_order_item') }} as m
      on d.id_magento = cast(m.order_item_id as varchar)
    where m.row_total <> 0
    group by d.id_magento
),

status_processing_costs as (
    select
        m.order_id,
        sum(coalesce(u.cost, d.cost)) as cost,
        sum(coalesce(u.averageweightedcost, d.averageweightedcost)) as cost_average_order
    from {{ ref('magento_sales_order_item') }} as m
    left join cost_unique_magento_id            as u  on cast(m.order_item_id as varchar) = u.id_magento
    left join cost_duplicate_magento_id_product as d  on cast(m.order_item_id as varchar) = d.id_magento
                                                   and cast(m.product_id as varchar)    = d.id_produto_magento
    left join cost_duplicate_magento_id_avg     as a2 on cast(m.order_item_id as varchar) = a2.id_magento
    group by m.order_id
)

select
    moi.order_item_id,
    moi.order_id,
    moi.product_id                          as magento_product_id,
    u.cost                                  as cost_unique,
    u.averageweightedcost                   as averageweightedcost_unique,
    d.cost                                  as cost_duplicate,
    d.averageweightedcost                   as averageweightedcost_duplicate,
    a2.cost                                 as cost_avg,
    a2.averageweightedcost                  as averageweightedcost_avg,
    sp.cost                                 as order_cost,
    sp.cost_average_order                   as order_cost_average

from {{ ref('magento_sales_order_item') }}         as moi
left join cost_unique_magento_id                   as u
       on cast(moi.order_item_id as varchar) = u.id_magento
left join cost_duplicate_magento_id_product        as d
       on cast(moi.order_item_id as varchar) = d.id_magento
      and cast(moi.product_id as varchar)    = d.id_produto_magento
left join cost_duplicate_magento_id_avg            as a2
       on cast(moi.order_item_id as varchar) = a2.id_magento
left join status_processing_costs                  as sp
       on moi.order_id      = sp.order_id
