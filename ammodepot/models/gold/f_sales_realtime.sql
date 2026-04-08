{# Real-time sales view built on f_sales instead of duplicating its CTE chain.
   Mirrors the full f_sales column set filtered to today's orders, then adds
   per-SKU and total order count metrics. Keeping the schema aligned with
   f_sales avoids Power BI "column does not exist" errors whenever a dashboard
   references a field that f_sales already exposes. #}

with today_sales as (
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
        TESTFC
    from {{ ref('f_sales') }}
    where cast(CREATED_AT as date) = cast(
        {{ convert_tz('UTC', var("ammodepot_timezone"), 'current_timestamp()') }} as date
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
from today_sales as l
cross join distinct_count as d
left join sku_order_counts as s on l.testsku = s.testsku
