-- f_sales.sql
--
-- Consolidated sales fact combining Magento orders and Fishbowl cost data,
-- with timezone conversion, freight allocation, and customer ranking.
--
-- Decomposed: cost logic is in int_fishbowl_order_cost,
--             freight logic is in int_magento_order_freight,
--             product conversion logic is in int_magento_product_conversion.
--
-- Note: The original model contained three unused CTEs (last_day_cost_all,
-- filtered_cost_all_prep, filtered_cost_all) that have been removed as dead code.
-- The unused CTE product_qty_sold has also been removed.

-- First interaction: join Magento orders with cost data from intermediate model
with interaction_base as (
    select
        -- Datetime converted to local timezone
        CONVERT_TIMEZONE(
          'UTC',
          '{{ var("ammodepot_timezone") }}',
          CAST(z.item_created_at as TIMESTAMP)
        )                                                   as created_at,

        -- IDs and quantities
        z.product_id,
        z.order_id,
        case
        when z.row_total <> 0
            then (z.quantity_ordered * z.row_total) / z.row_total
        else 0
        end as qty_ordered,

        -- discounts
        z.discount_amount,
        z.discount_invoiced,

        -- unique item key
        CAST(z.product_id as VARCHAR)
          || '@'
          || CAST(z.order_id    as VARCHAR)               as chave,

        -- cost (Magento or Fishbowl) and weighted average cost
        COALESCE(
          c.cost_unique,
          c.cost_duplicate,
          c.cost_avg,
          c.averageweightedcost_unique * z.quantity_ordered,
          c.averageweightedcost_duplicate * z.quantity_ordered,
          c.averageweightedcost_avg * z.quantity_ordered
        )                                                   as cost,
        COALESCE(
          c.averageweightedcost_unique,
          c.averageweightedcost_duplicate,
          c.averageweightedcost_avg
        )                                                   as averageweightedcost,

        -- taxation
        z.tax_amount,
        z.row_total
        - COALESCE(z.amount_refunded, 0)
        - COALESCE(z.discount_amount, 0)
        + COALESCE(z.discount_refunded, 0) as row_total,

        -- standardized increment_id alias
        o.order_increment_id                                 as increment_id,

        -- address and customer
        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code    as country,
        a.region,
        a.city,
        a.street_address  as street,
        a.phone_number    as telephone,
        o.customer_firstname || ' ' || o.customer_lastname  as customer_name,

        -- Additional metadata
        z.base_cost                                          as cost_magento,
        z.order_item_id                                      as id,
        o.order_status                                       as status,
        c.order_cost                                         as fishbowl_registeredcost,
        z.store_id,
        o.store_name,
        z.item_weight                                        as weight,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.sku                                                as testsku,
        z.applied_rule_ids,
        o.customer_id,
        z.vendor_id
    from {{ ref('magento_sales_order_item') }}        as z
    left join {{ ref('magento_sales_order') }}         as o  on z.order_id           = o.order_id
    left join {{ ref('magento_sales_order_address') }} as a  on o.billing_address_id = a.order_address_id
    left join {{ ref('int_fishbowl_order_cost') }}     as c  on z.order_item_id      = c.order_item_id
),

-- SKU fact base: enrich interaction_base with freight and conversion data
skubase as (
    select
        CAST(ib.created_at as DATE)                                as created_at,
        ib.created_at                                      as timedate,
        DATE_TRUNC('hour', ib.created_at)                  as tiniciodahora_copiar,
        TO_CHAR(DATE_TRUNC('hour', ib.created_at), 'HH24:MI:SS') as tiniciodaHora,
        ib.product_id,
        ib.order_id,

        /* quantity used (protects against div/0, result is always qty_ordered) */
        case
            when ib.row_total = 0 then 0
            else ib.qty_ordered
        end                                               as qty_ordered,

        ib.qty_ordered                                     as ordered,

        ib.discount_invoiced                               as discount_invoiced,
        ib.chave,

        case when ib.qty_ordered > 0 then ib.cost else null end as cost,
        ib.averageweightedcost                             as average_weighted_cost,

        ib.tax_amount                                      as tax_amount,
        ib.row_total                                       as row_total,

        ib.increment_id,
        ib.billing_address_id,
        ib.customer_email,

        ib.postcode,
        ib.country,
        ib.region,
        ib.city,
        ib.street,
        ib.telephone                                       as phone_number,
        ib.customer_name,

        ib.id                                              as order_item_id,
        UPPER(ib.status)                                   as order_status,     -- idem Snowflake
        ib.cost_magento,
        ib.fishbowl_registeredcost,
        ib.store_id,
        ib.store_name,
        ib.weight,


        fr.net_sales                                        as frsales,           -- order net sales
        fr.freight_amount                                  as fcost,             -- order total freight cost
        fr.total_weight                                    as weightorder,
        fr.product_count                                   as products_in_order,

        /* line weight as percentage of order total weight */
        ib.weight / NULLIF(fr.total_weight, 0)             as percentage,


        /* freight_revenue calculation, simplified but preserving original logic */
        case
            when fr.total_weight is null and ib.testsku not ilike '%parceldefender%' then
                -- div0null( safe_qty_from_div0 * ty.netsales, ctm.products * safe_qty_from_div0 )
                ( (case when ib.row_total = 0 then 0 else ib.qty_ordered end) * fr.net_sales )
                /
                NULLIF( (fr.product_count * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
            else
                -- div0null( z.weight * safe_qty_from_div0 * ty.netsales, mow.total_weight * safe_qty_from_div0 )
                ( ib.weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end) * fr.net_sales )
                /
                NULLIF( (fr.total_weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
        end as freight_revenue,

        /* freight_cost calculation, simplified but preserving original logic */
        case
            when fr.total_weight is null and ib.testsku not ilike '%parceldefender%' then
                -- div0null( safe_qty_from_div0, ctm.products * safe_qty_from_div0 ) * Freightamount
                (
                    (case when ib.row_total = 0 then 0 else ib.qty_ordered end)
                    /
                    NULLIF( (fr.product_count * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
                ) * fr.freight_amount
            else
                -- div0null( z.weight * safe_qty_from_div0, mow.total_weight * safe_qty_from_div0 ) * Freightamount
                (
                    (ib.weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end) )
                    /
                    NULLIF( (fr.total_weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
                ) * fr.freight_amount
        end as freight_cost,

        -- keeping original reference, ensure correct inclusion
        ps.part_qty_sold,
        COALESCE(ps.conversion, 1)                        as conversion,

        ib.product_options,
        ib.product_type,
        ib.parent_item_id,
        ib.testsku,
        ib.applied_rule_ids,
        ib.customer_id,
        ib.vendor_id                                      as vendor             -- renomeado
    from interaction_base              as ib
    left join {{ ref('int_magento_order_freight') }}  as fr
           on fr.order_id = ib.order_id

    left join {{ ref('int_magento_product_conversion') }} as ps
           on ps.item_id = ib.id
),

-- configurable items that will transfer metrics to child items
to_transfer as (
    select
        order_item_id as id,
        row_total,
        cost,
        freight_revenue,
        freight_cost,
        qty_ordered,
        part_qty_sold
    from skubase
    where product_type = 'configurable'
),

-- adjust child item using configurable (parent) item values, if exists
last as (
    select
        z.created_at,
        z.timedate,
        z.order_item_id,
        z.increment_id,
        z.tiniciodahora_copiar,
        z.product_id,
        z.order_id,
        z.timedate                       as trickat,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.testsku,
        z.conversion,
        z.tiniciodahora,
        z.customer_email                 as customer_email,
        z.postcode,
        z.country,
        z.region,
        z.city,
        z.street,
        z.phone_number                   as telephone,
        z.customer_name,
        z.store_id,
        z.order_status                   as status,
        z.vendor,
        z.customer_id,

        case when ty.id is not null then ty.row_total else z.row_total end as row_total,
        case when ty.id is not null then ty.cost else z.cost end as cost,
        case when ty.id is not null then ty.qty_ordered else z.qty_ordered end as qty_ordered,
        case when ty.id is not null then ty.part_qty_sold else z.part_qty_sold end as part_qty_sold,
        case when ty.id is not null then ty.freight_revenue else z.freight_revenue end as freight_revenue,
        case when ty.id is not null then ty.freight_cost else z.freight_cost end as freight_cost
     from skubase as z
    left join to_transfer as ty
           on ty.id = z.parent_item_id
),

last_day_cost_last as (
    select
        l.product_id,
        MAX(l.trickat) as last_scheduled_date
    from last as l
    where l.cost > 0
      and l.qty_ordered > 0
    group by l.product_id
),

filtered_cost_prep as (
    select
        l.product_id,
        l.cost,
        l.qty_ordered as qty,
        l.trickat
    from last as l
    inner join last_day_cost_last as ld
      on     l.product_id = ld.product_id
         and l.trickat    = ld.last_scheduled_date
    where l.cost > 0
      and l.qty_ordered > 0
),

filtered_cost_final as (
    select
        product_id,
        SUM(cost) / NULLIF(SUM(qty), 0) as cost,
        SUM(qty)                        as qty,
        trickat                         as trickat      -- informational only
    from filtered_cost_prep
    group by product_id, trickat
)

select
    l.created_at                            as CREATED_AT,
    l.timedate                              as TIMEDATE,
    l.order_item_id                         as ID,
    l.increment_id                          as INCREMENT_ID,
    l.tiniciodahora_copiar                  as "Início da Hora - Copiar",
    l.product_id                            as PRODUCT_ID,
    l.order_id                              as ORDER_ID,
    l.trickat                               as TRICKAT,
    l.product_options                       as PRODUCT_OPTIONS,
    l.product_type                          as PRODUCT_TYPE,
    l.parent_item_id                        as PARENT_ITEM_ID,
    l.testsku                               as TESTSKU,
    l.conversion                            as CONVERSION,
    l.tiniciodahora                         as "Início da Hora",
    l.customer_email                        as CUSTOMER_EMAIL,
    l.postcode                              as POSTCODE,
    l.country                               as COUNTRY,
    l.region                                as REGION,
    l.city                                  as CITY,
    l.street                                as STREET,
    l.telephone                             as TELEPHONE,
    l.customer_name                         as CUSTOMER_NAME,
    l.store_id                              as STORE_ID,
    l.status                                as STATUS,
    l.row_total                             as ROW_TOTAL,
    COALESCE(l.cost, fcf.cost * l.qty_ordered) as COST,
    l.qty_ordered                           as QTY_ORDERED,
    l.freight_revenue                       as FREIGHT_REVENUE,
    l.freight_cost                          as FREIGHT_COST,
    l.vendor                                as VENDOR,
    l.customer_id                           as CUSTOMER_ID,
    cu.rank_id                              as RANK_ID,
    COALESCE(l.part_qty_sold, l.qty_ordered) as PART_QTY_SOLD,
    null                                    as TESTC,
    null                                    as TESTR,
    null                                    as TESTFR,
    null                                    as TESTFC
from last as l
left join filtered_cost_final as fcf
  on fcf.product_id = l.product_id
left join {{ ref("magento_d_customerupdated") }} as cu
  on LOWER(
        COALESCE(
          NULLIF(l.customer_email, ''),
          '{{ var("ammodepot_default_customer_email") }}'
        )
     ) = cu.customer_email
where l.product_type <> 'configurable'
