-- int_fishbowl_order_cost
--
-- Computes item-level costs by cross-referencing Fishbowl and Magento data.
-- Handles unique vs. duplicate Magento ID resolution and aggregates costs per order.
--
-- Outputs one row per Magento order_item_id with:
--   cost_unique, averageweightedcost_unique           (from unique Magento ID cost)
--   cost_duplicate, averageweightedcost_duplicate     (from duplicate Magento ID cost, matched by product)
--   cost_avg, averageweightedcost_avg                 (from duplicate Magento ID cost, averaged)
--   order_cost, order_cost_average                    (from status_processing_costs, aggregated per order)

-- Fishbowl-to-Magento ID crosswalk lookups
with magento_identities as (
    select
        NULLIF(
          JSON_EXTRACT_PATH_TEXT(a.custom_fields, 'Magento Order Identity 1'),
          ''
        ) as magento_order_item_identity,
        a.sales_order_id as code
    from {{ ref('fishbowl_so') }} as a
    where JSON_EXTRACT_PATH_TEXT(a.custom_fields, 'Magento Order Identity 1') is not null
),

conversion_soitem as (
    select
        z.so_item_id as idfb,
        COALESCE(
            NULLIF(JSON_EXTRACT_PATH_TEXT(z.custom_fields, '25', 'value'), ''),
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

-- Real & Estimated Cost Segregation
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
        COUNT(*)              as count_of_id_magento,
        MAX(order_fishbowl_id) as order_fb
    from cost_test
    group by id_magento
),

-- UOM Conversion to base
uom_to_base as (
    select
        from_uom_id      as fromuomid,
        multiply_factor  as multiply,
        to_uom_id        as touomid
    from {{ ref('fishbowl_uomconversion') }}
    where to_uom_id = {{ var('ammodepot_base_uom_id') }}
),

-- Fishbowl product average cost
product_avg_cost as (
    select
        p.product_id                                  as id_produto,
        u.multiply                                    as conversion,
        COALESCE(c.average_cost * u.multiply, c.average_cost)
                                                     as averagecost,
        c.average_cost                                as costnoconversion
    from {{ ref('fishbowl_product') }}     as p
    left join {{ ref('fishbowl_partcost') }} as c on p.part_id  = c.part_id
    left join uom_to_base                       as u on p.uom_id  = u.fromuomid
),

-- Kit relationships
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
        COALESCE(
    NULLIF(SUM(CAST(s.total_cost as DECIMAL(38,9))),0),
    SUM(CAST(s.quantity_ordered as DECIMAL(38,9)) * CAST(a.averagecost as DECIMAL(38,9)))
) as cost,
        k.recordid2             as kitid,
        SUM(a.averagecost)      as costprocessing,
        MAX(s.quantity_ordered) as maxqtytest
    from {{ ref('fishbowl_soitem') }} as s
    left join product_avg_cost          as a on s.product_id = a.id_produto
    left join object_kit                as k on s.so_item_id  = k.recordid1
    where s.item_type_id = {{ var('ammodepot_sale_item_type_id') }}
      and s.product_description not ilike '%POLLYAMOBAG%'
    group by k.recordid2
),

-- Base Fishbowl cost linked to Magento IDs
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
        COALESCE(k.costprocessing, a.averagecost)                 as averageweightedcost,
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

-- Last-day cost per product
last_day_cost_fishbowl as (
    select
        id_produto_fishbowl             as product_id,
        MAX(scheduled_fulfillment_date) as last_scheduled_date
    from cost_fishbowl_base
    where cost is not null and cost > 0
    group by id_produto_fishbowl
),

filtered_cost_fishbowl as (
    select
        f.id_produto_fishbowl         as product_id,
        AVG(f.cost / NULLIF(f.qty,0)) as cost
    from cost_fishbowl_base as f
    inner join last_day_cost_fishbowl     as ld
      on f.id_produto_fishbowl         = ld.product_id
     and f.scheduled_fulfillment_date = ld.last_scheduled_date
    where f.cost is not null and f.cost > 0
    group by f.id_produto_fishbowl
),

-- Final Fishbowl cost
cost_fishbowl_final as (
    select
        COALESCE(NULLIF(b.total_cost,0), NULLIF(k.cost,0)) as cost,
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
        COALESCE(k.costprocessing, a.averagecost)                 as averageweightedcost,
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

-- Costs where Magento ID is unique
cost_unique_magento_id as (
    select f.*
    from cost_fishbowl_final   as f
    inner join cost_aggregation      as ca on f.id_magento      = ca.id
    where ca.count_of_id_magento = 1
),

-- Average costs when Magento ID appears multiple times
cost_duplicate_magento_id_product as (
    select
        AVG(f.cost)                as cost,
        f.id_magento               as id_magento,
        AVG(f.averageweightedcost) as averageweightedcost,
        f.id_produto_magento       as id_produto_magento
    from cost_fishbowl_final    as f
    inner join cost_aggregation       as ca on f.id_magento      = ca.id
    where ca.count_of_id_magento > 1
    group by f.id_magento, f.id_produto_magento
),

-- Further average for duplicated IDs, filtering out zero-total orders
cost_duplicate_magento_id_avg as (
    select
        AVG(d.cost)                as cost,
        AVG(d.averageweightedcost) as averageweightedcost,
        d.id_magento
    from cost_duplicate_magento_id_product as d
    inner join {{ ref('magento_sales_order_item') }} as m
      on d.id_magento = m.order_item_id
    where m.row_total <> 0
    group by d.id_magento
),

-- Aggregate Fishbowl costs per Magento order
status_processing_costs as (
    select
        m.order_id,
        SUM(COALESCE(u.cost, d.cost)) as cost,
        SUM(COALESCE(u.averageweightedcost, d.averageweightedcost)) as cost_average_order
    from {{ ref('magento_sales_order_item') }} as m
    left join cost_unique_magento_id            as u  on m.order_item_id = u.id_magento
    left join cost_duplicate_magento_id_product as d  on m.order_item_id = d.id_magento
                                                   and m.product_id    = d.id_produto_magento
    left join cost_duplicate_magento_id_avg     as a2 on m.order_item_id = a2.id_magento
    group by m.order_id
)

-- Final output: one row per Magento order item with all cost variants
select
    moi.order_item_id,
    moi.order_id,
    moi.product_id                          as magento_product_id,

    -- Unique Magento ID cost
    u.cost                                  as cost_unique,
    u.averageweightedcost                   as averageweightedcost_unique,

    -- Duplicate Magento ID cost (matched by product)
    d.cost                                  as cost_duplicate,
    d.averageweightedcost                   as averageweightedcost_duplicate,

    -- Duplicate Magento ID cost (averaged)
    a2.cost                                 as cost_avg,
    a2.averageweightedcost                  as averageweightedcost_avg,

    -- Order-level aggregated cost
    sp.cost                                 as order_cost,
    sp.cost_average_order                   as order_cost_average

from {{ ref('magento_sales_order_item') }}         as moi
left join cost_unique_magento_id                   as u
       on moi.order_item_id = u.id_magento
left join cost_duplicate_magento_id_product        as d
       on moi.order_item_id = d.id_magento
      and moi.product_id    = d.id_produto_magento
left join cost_duplicate_magento_id_avg            as a2
       on moi.order_item_id = a2.id_magento
left join status_processing_costs                  as sp
       on moi.order_id      = sp.order_id
