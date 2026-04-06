{# Real-time sales view built on f_sales instead of duplicating its CTE chain.
   Filters to today's orders and adds per-SKU and total order count metrics. #}

with today_sales as (
    select
        CREATED_AT,
        TIMEDATE,
        TIMEDATE                                    as TRICKAT,
        PRODUCT_ID,
        ORDER_ID,
        ROW_TOTAL,
        COST                                        as BASE_COST,
        TESTSKU,
        PRODUCT_TYPE
    from {{ ref('f_sales') }}
    where cast(CREATED_AT as date) = cast(
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'current_timestamp') }} as date
    )
),

distinct_count as (
    select count(distinct order_id) as distinct_order_id_count
    from today_sales
),

sku_order_counts as (
    select
        testsku,
        count(distinct order_id) as distinct_order_id_by_testsku
    from today_sales
    group by testsku
)

select
    l.CREATED_AT,
    l.TIMEDATE,
    l.TRICKAT,
    l.PRODUCT_ID,
    l.ORDER_ID,
    l.ROW_TOTAL,
    l.BASE_COST,
    l.TESTSKU,
    l.PRODUCT_TYPE,
    d.distinct_order_id_count                   as DISTINCT_ORDER_ID_COUNT,
    s.distinct_order_id_by_testsku              as DISTINCT_ORDER_ID_BY_TESTSKU
from today_sales as l
cross join distinct_count as d
left join sku_order_counts as s on l.testsku = s.testsku
