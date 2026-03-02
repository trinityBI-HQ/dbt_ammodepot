with conversion_so as (
    select
        f.record_id  as produtofish,
        f.channel_id as produto_magento
    from {{ ref('fishbowl_plugininfo') }} as f
    where f.related_table_name = 'SO'
),

ups_shipment_cost as (
    select
        tracking_number,
        sum(net_amount)          as net_amount
    from {{ ref('magento_ups_invoice') }}
    group by tracking_number
),

fishbowl_shipment_costs as (
    select
        fs.sales_order_id                                         as soid,
        coalesce(sum(usc.net_amount), sum(sc.freight_amount))     as freight_amount,
        sum(sc.freight_weight)                                    as freight_weight,
        avg(fs.carrier_service_id)                                as carrier_service_id,
        sum(usc.net_amount)                                       as amount_ups,
        count(sc.tracking_number)    as packagenumb
    from {{ ref('fishbowl_ship') }}            as fs
    left join {{ ref('fishbowl_shipcarton') }} as sc
      on fs.shipment_id = sc.shipment_id
    left join ups_shipment_cost               as usc
      on sc.tracking_number = usc.tracking_number
    group by fs.sales_order_id
),

magento_freight_info as (
    select
        pc.produto_magento        as order_magento,
        avg(fb2.freight_amount)   as freight_amount,
        avg(fb2.freight_weight)   as freight_weight,
        avg(fb2.carrier_service_id) as carrier_service_id
    from {{ ref('fishbowl_so') }}            as fb
    left join fishbowl_shipment_costs       as fb2 on fb.sales_order_id = fb2.soid
    left join conversion_so                  as pc  on fb.sales_order_id = pc.produtofish
    group by pc.produto_magento
),

magento_order_items_for_freight as (
     select
         m.item_weight                         as weight,
        m.order_id                            as order_id,
        m.sku,
        m.product_id,
        m.quantity_ordered                    as qty_ordered,
        case
            when m.row_total = 0 then 0
            else m.quantity_ordered
         end                                   as test,
        m.row_total
            - coalesce(m.amount_refunded, 0)
            - coalesce(m.discount_amount, 0)
            + coalesce(m.discount_refunded, 0)
         as row_total
    from {{ ref('magento_sales_order_item') }} as m
    left join {{ ref('magento_catalog_product_entity') }} as ct
        on m.product_id = ct.product_entity_id
    where (m.row_total
            - coalesce(m.amount_refunded, 0)
            - coalesce(m.discount_amount, 0)
            + coalesce(m.discount_refunded, 0)) <> 0
        and m.quantity_ordered <> 0
        and ct.sku not ilike '%parceldefender%'
),

magento_order_weight as (
    select
        order_id,
        sum(weight)       as total_weight,
        count(product_id) as product_count
    from magento_order_items_for_freight
    group by order_id
),

magento_order_shipping_agg as (
    select
        ms.order_id,
        sum(ms.shipping_amount)               as shipping_amount,
        sum(ms.base_shipping_amount)          as base_shipping_amount,
        sum(ms.base_shipping_canceled)        as base_shipping_canceled,
        sum(ms.base_shipping_discount_amount) as base_shipping_discount_amount,
        sum(ms.base_shipping_refunded)        as base_shipping_refunded,
        sum(ms.base_shipping_tax_amount)      as base_shipping_tax_amount,
        sum(ms.base_shipping_tax_refunded)    as base_shipping_tax_refunded,
        sum(
          coalesce(ms.base_shipping_amount, 0)
          - coalesce(ms.base_shipping_tax_amount, 0)
          - coalesce(ms.base_shipping_refunded, 0)
          + coalesce(ms.base_shipping_tax_refunded, 0)
        )   as net_sales,
        sum(mfi.freight_amount) as freight_amount
    from {{ ref('magento_sales_order') }}     as ms
    left join magento_freight_info           as mfi
      on ms.order_id = mfi.order_magento
    group by ms.order_id
)

select
    mosa.order_id,
    mosa.shipping_amount,
    mosa.base_shipping_amount,
    mosa.base_shipping_canceled,
    mosa.base_shipping_discount_amount,
    mosa.base_shipping_refunded,
    mosa.base_shipping_tax_amount,
    mosa.base_shipping_tax_refunded,
    mosa.net_sales,
    mosa.freight_amount,
    mow.total_weight,
    mow.product_count
from magento_order_shipping_agg as mosa
left join magento_order_weight  as mow
       on mosa.order_id = mow.order_id
