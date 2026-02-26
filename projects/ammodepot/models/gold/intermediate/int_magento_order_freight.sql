-- int_magento_order_freight
--
-- Computes freight allocation data per Magento order by combining:
--   - UPS invoice costs (Magento source)
--   - Fishbowl shipment costs enriched with UPS data
--   - Fishbowl-to-Magento order mapping via conversion_so
--   - Per-item weight allocation within each order
--
-- Outputs one row per order_id with:
--   net_sales, freight_amount (from magento_order_shipping_agg)
--   total_weight, product_count (from magento_order_weight)

-- Fishbowl SO-to-Magento order ID mapping
with conversion_so as (
    select
        f.record_id  as produtofish,
        f.channel_id as produto_magento
    from {{ ref('fishbowl_plugininfo') }} as f
    where f.related_table_name = 'SO'
),

-- UPS shipment costs (Magento source)
ups_shipment_cost as (
    select
        tracking_number,
        SUM(net_amount)          as net_amount
    from {{ ref('magento_ups_invoice') }}
    group by tracking_number
),

-- Fishbowl shipment costs enriched with UPS
fishbowl_shipment_costs as (
    select
        fs.sales_order_id                                         as soid,
        COALESCE(SUM(usc.net_amount), SUM(sc.freight_amount))     as freight_amount,
        SUM(sc.freight_weight)                                    as freight_weight,
        AVG(fs.carrier_service_id)                                as carrier_service_id,
        SUM(usc.net_amount)                                       as amount_ups,
        COUNT(sc.tracking_number)    as packagenumb
    from {{ ref('fishbowl_ship') }}            as fs
    left join {{ ref('fishbowl_shipcarton') }} as sc
      on fs.shipment_id = sc.shipment_id
    left join ups_shipment_cost               as usc
      on sc.tracking_number = usc.tracking_number
    group by fs.sales_order_id
),

-- Bring Fishbowl freight into Magento context
magento_freight_info as (
    select
        pc.produto_magento        as order_magento,
        AVG(fb2.freight_amount)   as freight_amount,
        AVG(fb2.freight_weight)   as freight_weight,
        AVG(fb2.carrier_service_id) as carrier_service_id
    from {{ ref('fishbowl_so') }}            as fb
    left join fishbowl_shipment_costs       as fb2 on fb.sales_order_id = fb2.soid
    left join conversion_so                  as pc  on fb.sales_order_id = pc.produtofish
    group by pc.produto_magento
),

-- Items eligible for freight allocation (non-zero row totals, non-parcel-defender)
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
            - COALESCE(m.amount_refunded, 0)
            - COALESCE(m.discount_amount, 0)
            + COALESCE(m.discount_refunded, 0)
         as row_total
    from {{ ref('magento_sales_order_item') }} as m
    left join {{ ref('magento_catalog_product_entity') }} as ct
        on m.product_id = ct.product_entity_id
    where (m.row_total
            - COALESCE(m.amount_refunded, 0)
            - COALESCE(m.discount_amount, 0)
            + COALESCE(m.discount_refunded, 0)) <> 0
        and m.quantity_ordered <> 0
        and ct.sku not ilike '%parceldefender%'
),

-- Sum total weight per order
magento_order_weight as (
    select
        order_id,
        SUM(weight)       as total_weight,
        COUNT(product_id) as product_count
    from magento_order_items_for_freight
    group by order_id
),

-- Allocate shipping cost per order
magento_order_shipping_agg as (
    select
        ms.order_id,
        SUM(ms.shipping_amount)               as shipping_amount,
        SUM(ms.base_shipping_amount)          as base_shipping_amount,
        SUM(ms.base_shipping_canceled)        as base_shipping_canceled,
        SUM(ms.base_shipping_discount_amount) as base_shipping_discount_amount,
        SUM(ms.base_shipping_refunded)        as base_shipping_refunded,
        SUM(ms.base_shipping_tax_amount)      as base_shipping_tax_amount,
        SUM(ms.base_shipping_tax_refunded)    as base_shipping_tax_refunded,
        SUM(
          COALESCE(ms.base_shipping_amount, 0)
          - COALESCE(ms.base_shipping_tax_amount, 0)
          - COALESCE(ms.base_shipping_refunded, 0)
          + COALESCE(ms.base_shipping_tax_refunded, 0)
        )   as net_sales,
        SUM(mfi.freight_amount) as freight_amount
    from {{ ref('magento_sales_order') }}     as ms
    left join magento_freight_info           as mfi
      on ms.order_id = mfi.order_magento
    group by ms.order_id
)

-- Final output: one row per order with freight allocation data
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
