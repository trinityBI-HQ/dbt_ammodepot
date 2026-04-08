{# Real-time sales view built on f_sales instead of duplicating its CTE chain.
   Mirrors the full f_sales column set filtered to the last 4 days of orders
   (matching the legacy AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS window),
   then adds per-day order count metrics. Power BI's TODAY/Yesterday filters
   apply a date slicer in DAX, so the view must contain BOTH today and
   yesterday at minimum. The order-count aggregates are partitioned by
   sale_date so each row reports its own day's count, not a cross-day total. #}

with recent_sales as (
    select
        CREATED_AT,
        TIMEDATE,
        ID,
        INCREMENT_ID,
        "Início da Hora - Copiar",
        PRODUCT_ID,
        ORDER_ID,
        TRICKAT,
        PRODUCT_OPTIONS,
        PRODUCT_TYPE,
        PARENT_ITEM_ID,
        TESTSKU,
        CONVERSION,
        "Início da Hora",
        CUSTOMER_EMAIL,
        POSTCODE,
        COUNTRY,
        REGION,
        CITY,
        STREET,
        TELEPHONE,
        CUSTOMER_NAME,
        STORE_ID,
        STOREFRONT,
        STATUS,
        ROW_TOTAL,
        COST,
        QTY_ORDERED,
        FREIGHT_REVENUE,
        FREIGHT_COST,
        VENDOR,
        CUSTOMER_ID,
        RANK_ID,
        PART_QTY_SOLD,
        TESTC,
        TESTR,
        TESTFR,
        TESTFC,
        cast(CREATED_AT as date) as sale_date
    from {{ ref('f_sales') }}
    where cast(CREATED_AT as date) >= dateadd(
        day, -4,
        cast(
            {{ convert_tz('UTC', var("ammodepot_timezone"), 'current_timestamp()') }} as date
        )
    )
),

distinct_count_by_day as (
    select
        sale_date,
        count(distinct order_id) as distinct_order_id_count
    from recent_sales
    group by sale_date
),

sku_order_counts_by_day as (
    select
        sale_date,
        testsku,
        count(distinct order_id) as distinct_order_id_by_testsku
    from recent_sales
    group by sale_date, testsku
)

select
    l.CREATED_AT,
    l.TIMEDATE,
    l.ID,
    l.INCREMENT_ID,
    l."Início da Hora - Copiar",
    l.PRODUCT_ID,
    l.ORDER_ID,
    l.ORDER_ID                                  as ID_RFV,
    l.TRICKAT,
    l.PRODUCT_OPTIONS,
    l.PRODUCT_TYPE,
    l.PARENT_ITEM_ID,
    l.TESTSKU,
    l.CONVERSION,
    l."Início da Hora",
    l.CUSTOMER_EMAIL,
    l.POSTCODE,
    l.COUNTRY,
    l.REGION,
    l.CITY,
    l.STREET,
    l.TELEPHONE,
    l.CUSTOMER_NAME,
    l.STORE_ID,
    l.STOREFRONT,
    l.STATUS,
    l.ROW_TOTAL,
    l.COST,
    l.COST                                      as BASE_COST,
    l.QTY_ORDERED,
    l.FREIGHT_REVENUE,
    l.FREIGHT_COST,
    l.VENDOR,
    l.CUSTOMER_ID,
    l.RANK_ID,
    l.PART_QTY_SOLD,
    l.TESTC,
    l.TESTR,
    l.TESTFR,
    l.TESTFC,
    d.distinct_order_id_count                   as DISTINCT_ORDER_ID_COUNT,
    s.distinct_order_id_by_testsku              as DISTINCT_ORDER_ID_BY_TESTSKU
from recent_sales as l
left join distinct_count_by_day as d
       on d.sale_date = l.sale_date
left join sku_order_counts_by_day as s
       on s.sale_date = l.sale_date
      and s.testsku = l.testsku
