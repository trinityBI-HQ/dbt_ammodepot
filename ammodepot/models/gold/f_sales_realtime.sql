with interaction as (
    select
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'cast(z.item_created_at as timestamp)') }} as created_at,
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'cast(z.item_created_at as timestamp)') }} as timedate,
        z.item_created_at                                           as trickat,
        z.product_id                                                as product_id,
        z.order_id                                                  as order_id,
        z.row_total
            - coalesce(z.amount_refunded, 0)
            - coalesce(z.discount_amount, 0)
            + coalesce(z.discount_refunded, 0)                      as row_total,
        z.base_cost,
        z.sku                                                       as testsku,
        z.product_type                                              as product_type,
        z.order_item_id                                             as id,
        z.parent_item_id
    from {{ ref('magento_sales_order_item') }} as z
    inner join {{ ref('magento_sales_order') }} as t
      on z.order_id = t.order_id
    where t.created_at >= dateadd(day, -4, current_date())
),

to_transfer as (
    select
        id,
        product_id,
        base_cost,
        row_total as config_row_total
    from interaction
    where product_type = 'configurable'
),

last_step as (
    select
        i.created_at,
        i.timedate,
        i.trickat,
        i.product_id,
        i.order_id,
        case
            when t.id is not null then t.config_row_total
            else i.row_total
        end as row_total,
        case
            when t.id is not null then t.base_cost
            else i.base_cost
        end as base_cost,
        i.testsku,
        i.product_type
    from interaction as i
    left join to_transfer as t
      on i.parent_item_id = t.id
    where i.product_type <> 'configurable'
),

last_today as (
    select *
    from last_step
    where cast(created_at as date) = cast(
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'current_timestamp()') }} as date
    )
),

distinct_count as (
    select count(distinct order_id) as distinct_order_id_count
    from last_today
),

sku_order_counts as (
    select
        testsku,
        count(distinct order_id) as distinct_order_id_by_testsku
    from last_today
    group by testsku
)

select
    l.created_at                                as CREATED_AT,
    l.timedate                                  as TIMEDATE,
    l.trickat                                   as TRICKAT,
    l.product_id                                as PRODUCT_ID,
    l.order_id                                  as ORDER_ID,
    l.row_total                                 as ROW_TOTAL,
    l.base_cost                                 as BASE_COST,
    l.testsku                                   as TESTSKU,
    l.product_type                              as PRODUCT_TYPE,
    d.distinct_order_id_count                   as DISTINCT_ORDER_ID_COUNT,
    s.distinct_order_id_by_testsku              as DISTINCT_ORDER_ID_BY_TESTSKU
from last_today as l
cross join distinct_count as d
left join sku_order_counts as s on l.testsku = s.testsku
