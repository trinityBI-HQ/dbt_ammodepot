{# GunBroker sales from Fishbowl-only orders.

   GunBroker orders exist only in Fishbowl (not Magento) and are identified
   by the 'GB' prefix on the SO number. This intermediate shapes them to
   match the f_sales 36-column schema so they can be UNION ALL'd in.

   ID convention: negative values (−1 × Fishbowl PK) avoid collision
   with positive Magento IDs used in the main f_sales branch.

   Freight: aggregated from fishbowl_ship/shipcarton/UPS invoice per order,
   then allocated to each line item by revenue proportion.

   UOM: conversion factor from fishbowl_uomconversion applied to qty. #}

with gunbroker_orders as (
    select
        so.sales_order_id,
        so.sales_order_number,
        so.status_id,
        so.customer_email,
        so.customer_phone,
        so.bill_to_name,
        so.bill_to_address,
        so.bill_to_city,
        so.bill_to_zip,
        so.created_at
    from {{ ref('fishbowl_so') }} as so
    where so.sales_order_number like
        '{{ var("ammodepot_gunbroker_order_prefix") }}%'
),

gunbroker_items as (
    select
        si.so_item_id,
        si.sales_order_id,
        si.product_id,
        si.product_number,
        si.quantity_ordered,
        si.total_price,
        si.total_cost
    from {{ ref('fishbowl_soitem') }} as si
    where si.item_type_id = {{ var('ammodepot_sale_item_type_id') }}
),

{# Map Fishbowl product_id → Magento product_entity_id via plugininfo #}
product_mapping as (
    select
        pi.record_id  as fishbowl_product_id,
        pi.channel_id as magento_product_id
    from {{ ref('fishbowl_plugininfo') }} as pi
    where pi.related_table_name = 'Product'
),

{# UOM conversion: Fishbowl product → base UOM multiply factor #}
uom_conversion as (
    select
        pr.product_id,
        coalesce(uom.multiply_factor, 1) as conversion
    from {{ ref('fishbowl_product') }} as pr
    left join {{ ref('fishbowl_uomconversion') }} as uom
        on pr.uom_id = uom.from_uom_id
        and uom.to_uom_id = {{ var('ammodepot_base_uom_id') }}
),

{# Freight per order: same pattern as int_magento_order_freight
   fishbowl_shipment_costs CTE — ship → shipcarton → UPS invoice #}
ups_costs as (
    select
        tracking_number,
        sum(net_amount) as net_amount
    from {{ ref('magento_ups_invoice') }}
    group by tracking_number
),

order_freight as (
    select
        fs.sales_order_id,
        coalesce(sum(ups.net_amount), sum(sc.freight_amount)) as freight_cost,
        sum(sc.freight_weight)                                as freight_weight
    from {{ ref('fishbowl_ship') }} as fs
    left join {{ ref('fishbowl_shipcarton') }} as sc
        on fs.shipment_id = sc.shipment_id
    left join ups_costs as ups
        on sc.tracking_number = ups.tracking_number
    group by fs.sales_order_id
),

{# Revenue per order for freight allocation by revenue proportion #}
order_revenue as (
    select
        si.sales_order_id,
        sum(si.total_price) as order_total
    from gunbroker_items as si
    group by si.sales_order_id
),

{# Reuse the same rank lookup that f_sales uses #}
customer_rank as (
    select
        cu.customer_email,
        cu.rank_id
    from {{ ref('magento_d_customerupdated') }} as cu
),

joined as (
    select
        {# Timezone conversion — same pattern as f_sales interaction_base.
           Fishbowl created_at comes through Iceberg as TIMESTAMP_LTZ;
           convert to Eastern wall clock then strip to NTZ for PBI compat. #}
        cast(
            convert_timezone(
                '{{ var("ammodepot_timezone") }}',
                o.created_at
            ) as timestamp_ntz
        )                                               as created_at_ntz,

        (-1) * si.so_item_id                            as id,
        o.sales_order_number                            as increment_id,
        coalesce(
            cast(pm.magento_product_id as number),
            (-1) * si.product_id
        )                                               as product_id,
        (-1) * o.sales_order_id                         as order_id,

        si.product_number                               as testsku,

        o.customer_email,
        o.bill_to_zip                                   as postcode,
        o.bill_to_city                                  as city,
        o.bill_to_address                               as street,
        o.customer_phone                                as telephone,
        o.bill_to_name                                  as customer_name,

        {# Map Fishbowl status_id to Magento-compatible text statuses
           so existing Streamlit default filters work (COMPLETE, PROCESSING).
           Fishbowl lifecycle: 10 Estimate → 20 Issued → 25 In Progress
           → 30 Fulfilled → 60 Historical (archived after completion).
           40 = Closed Short (partial), 50 = Void. #}
        case
            when o.status_id in (20, 25) then 'PROCESSING'
            when o.status_id in (30, 40, 60) then 'COMPLETE'
            when o.status_id = 50        then 'CANCELED'
            else 'ESTIMATE'
        end                                             as status,

        si.total_price                                  as row_total,
        si.total_cost                                   as cost,
        si.quantity_ordered                              as qty_ordered,

        {# Freight allocated to this line item by revenue proportion #}
        case
            when orev.order_total > 0
            then fr.freight_cost * (si.total_price / orev.order_total)
            else fr.freight_cost / nullif(
                count(*) over (partition by o.sales_order_id), 0
            )
        end                                             as freight_cost,

        {# UOM conversion factor #}
        coalesce(uc.conversion, 1)                      as conversion,

        cr.rank_id
    from gunbroker_items as si
    inner join gunbroker_orders as o
        on si.sales_order_id = o.sales_order_id
    left join product_mapping as pm
        on si.product_id = pm.fishbowl_product_id
    left join uom_conversion as uc
        on si.product_id = uc.product_id
    left join order_freight as fr
        on o.sales_order_id = fr.sales_order_id
    left join order_revenue as orev
        on o.sales_order_id = orev.sales_order_id
    left join customer_rank as cr
        on lower(
            coalesce(
                nullif(o.customer_email, ''),
                '{{ var("ammodepot_default_customer_email") }}'
            )
        ) = cr.customer_email
)

select
    cast(j.created_at_ntz as date)                      as CREATED_AT,
    j.created_at_ntz                                    as TIMEDATE,
    j.id                                                as ID,
    j.increment_id                                      as INCREMENT_ID,
    date_trunc('hour', j.created_at_ntz)                as "Início da Hora - Copiar",
    j.product_id                                        as PRODUCT_ID,
    j.order_id                                          as ORDER_ID,
    j.created_at_ntz                                    as TRICKAT,
    cast(null as varchar)                               as PRODUCT_OPTIONS,
    'simple'                                            as PRODUCT_TYPE,
    cast(null as number)                                as PARENT_ITEM_ID,
    j.testsku                                           as TESTSKU,
    j.conversion                                        as CONVERSION,
    {{ format_timestamp("date_trunc('hour', j.created_at_ntz)", 'HH24:MI:SS') }}
                                                        as "Início da Hora",
    j.customer_email                                    as CUSTOMER_EMAIL,
    j.postcode                                          as POSTCODE,
    'US'                                                as COUNTRY,
    cast(null as varchar)                               as REGION,
    j.city                                              as CITY,
    j.street                                            as STREET,
    j.telephone                                         as TELEPHONE,
    j.customer_name                                     as CUSTOMER_NAME,
    cast(null as number)                                as STORE_ID,
    '{{ var("ammodepot_gunbroker_store_name") }}'       as STOREFRONT,
    j.status                                            as STATUS,
    j.row_total                                         as ROW_TOTAL,
    j.cost                                              as COST,
    j.qty_ordered                                       as QTY_ORDERED,
    cast(null as number)                                as FREIGHT_REVENUE,
    j.freight_cost                                      as FREIGHT_COST,
    cast(null as number)                                as VENDOR,
    cast(null as number)                                as CUSTOMER_ID,
    j.rank_id                                           as RANK_ID,
    j.qty_ordered * j.conversion                        as PART_QTY_SOLD,
    cast(null as number)                                as TESTC,
    cast(null as number)                                as TESTR,
    cast(null as number)                                as TESTFR,
    cast(null as number)                                as TESTFC
from joined as j
