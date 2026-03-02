with interaction_base as (
    select
        convert_timezone(
          'UTC',
          '{{ var("ammodepot_timezone") }}',
          cast(z.item_created_at as timestamp)
        )                                                   as created_at,

        z.product_id,
        z.order_id,
        case
        when z.row_total <> 0
            then (z.quantity_ordered * z.row_total) / z.row_total
        else 0
        end as qty_ordered,

        z.discount_amount,
        z.discount_invoiced,

        cast(z.product_id as varchar)
          || '@'
          || cast(z.order_id    as varchar)               as chave,

        coalesce(
          c.cost_unique,
          c.cost_duplicate,
          c.cost_avg,
          c.averageweightedcost_unique * z.quantity_ordered,
          c.averageweightedcost_duplicate * z.quantity_ordered,
          c.averageweightedcost_avg * z.quantity_ordered
        )                                                   as cost,
        coalesce(
          c.averageweightedcost_unique,
          c.averageweightedcost_duplicate,
          c.averageweightedcost_avg
        )                                                   as averageweightedcost,

        z.tax_amount,
        z.row_total
        - coalesce(z.amount_refunded, 0)
        - coalesce(z.discount_amount, 0)
        + coalesce(z.discount_refunded, 0) as row_total,

        o.order_increment_id                                 as increment_id,

        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code    as country,
        a.region,
        a.city,
        a.street_address  as street,
        a.phone_number    as telephone,
        o.customer_firstname || ' ' || o.customer_lastname  as customer_name,

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

skubase as (
    select
        cast(ib.created_at as date)                                as created_at,
        ib.created_at                                      as timedate,
        date_trunc('hour', ib.created_at)                  as tiniciodahora_copiar,
        to_char(date_trunc('hour', ib.created_at), 'HH24:MI:SS') as tiniciodaHora,
        ib.product_id,
        ib.order_id,

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
        upper(ib.status)                                   as order_status,
        ib.cost_magento,
        ib.fishbowl_registeredcost,
        ib.store_id,
        ib.store_name,
        ib.weight,


        fr.net_sales                                        as frsales,
        fr.freight_amount                                  as fcost,
        fr.total_weight                                    as weightorder,
        fr.product_count                                   as products_in_order,

        ib.weight / nullif(fr.total_weight, 0)             as percentage,


        case
            when fr.total_weight is null and ib.testsku not ilike '%parceldefender%' then
                ( (case when ib.row_total = 0 then 0 else ib.qty_ordered end) * fr.net_sales )
                /
                nullif( (fr.product_count * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
            else
                ( ib.weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end) * fr.net_sales )
                /
                nullif( (fr.total_weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
        end as freight_revenue,

        case
            when fr.total_weight is null and ib.testsku not ilike '%parceldefender%' then
                (
                    (case when ib.row_total = 0 then 0 else ib.qty_ordered end)
                    /
                    nullif( (fr.product_count * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
                ) * fr.freight_amount
            else
                (
                    (ib.weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end) )
                    /
                    nullif( (fr.total_weight * (case when ib.row_total = 0 then 0 else ib.qty_ordered end)), 0)
                ) * fr.freight_amount
        end as freight_cost,

        ps.part_qty_sold,
        coalesce(ps.conversion, 1)                        as conversion,

        ib.product_options,
        ib.product_type,
        ib.parent_item_id,
        ib.testsku,
        ib.applied_rule_ids,
        ib.customer_id,
        ib.vendor_id                                      as vendor
    from interaction_base              as ib
    left join {{ ref('int_magento_order_freight') }}  as fr
           on fr.order_id = ib.order_id

    left join {{ ref('int_magento_product_conversion') }} as ps
           on ps.item_id = ib.id
),

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
        case when ty.id is not null then ty.freight_cost else z.freight_cost end as freight_cost,
        ty.cost            as testc,
        ty.row_total       as testr,
        ty.freight_revenue as testfr,
        ty.freight_cost    as testfc
     from skubase as z
    left join to_transfer as ty
           on ty.id = z.parent_item_id
),

last_day_cost_last as (
    select
        l.product_id,
        max(l.trickat) as last_scheduled_date
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
        sum(cost) / nullif(sum(qty), 0) as cost,
        sum(qty)                        as qty,
        trickat                         as trickat
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
    coalesce(l.cost, fcf.cost * l.qty_ordered) as COST,
    l.qty_ordered                           as QTY_ORDERED,
    l.freight_revenue                       as FREIGHT_REVENUE,
    l.freight_cost                          as FREIGHT_COST,
    l.vendor                                as VENDOR,
    l.customer_id                           as CUSTOMER_ID,
    cu.rank_id                              as RANK_ID,
    coalesce(l.part_qty_sold, l.qty_ordered) as PART_QTY_SOLD,
    l.testc                                 as TESTC,
    l.testr                                 as TESTR,
    l.testfr                                as TESTFR,
    l.testfc                                as TESTFC
from last as l
left join filtered_cost_final as fcf
  on fcf.product_id = l.product_id
left join {{ ref("magento_d_customerupdated") }} as cu
  on lower(
        coalesce(
          nullif(l.customer_email, ''),
          '{{ var("ammodepot_default_customer_email") }}'
        )
     ) = cu.customer_email
where l.product_type <> 'configurable'
