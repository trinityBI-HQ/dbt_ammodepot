-- int_magento_product_conversion
--
-- Aggregates piece-level sales for UOM conversion calculation.
-- Joins Magento order items with Fishbowl product/part data to compute
-- the total parts quantity sold per order item, applying UOM conversion factors.
--
-- Outputs one row per order_item_id with:
--   part_qty_sold (quantity * UOM conversion factor)
--   conversion    (the UOM multiply factor, defaulting to 1)
--   sku           (product SKU from catalog)

select
    s.order_item_id                                                   as item_id,
    SUM(s.quantity_ordered * COALESCE(uom.multiply_factor, 1))         as part_qty_sold,
    AVG(COALESCE(uom.multiply_factor, 1))                              as conversion,
    cpe.sku
from {{ ref('magento_sales_order_item') }}       as s
inner join {{ ref('magento_sales_order') }}             as o       on  s.order_id = o.order_id
inner join {{ ref('magento_catalog_product_entity') }}  as cpe     on  s.product_id = cpe.product_entity_id
inner join {{ ref('fishbowl_product') }}                as pr      on  cpe.sku = pr.product_number
inner join {{ ref('fishbowl_part') }}                   as p       on  pr.part_id = p.part_id
left join {{ ref('fishbowl_uomconversion') }}    as uom
  on s.product_id = uom.from_uom_id
 and uom.to_uom_id = {{ var('ammodepot_base_uom_id') }}
where s.product_type <> 'bundle'
  and s.row_total <> 0
group by s.order_item_id, cpe.sku
