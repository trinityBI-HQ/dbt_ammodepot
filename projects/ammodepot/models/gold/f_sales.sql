{{
  config(
    materialized = 'table',
    schema = 'gold'
  )
}}

WITH magento_identities AS (
    SELECT
        json_extract_path_text(custom_fields, 'Magento Order Identity 1') AS magento_order_item_identity,
        so_id AS code
    FROM {{ ref('fishbowl_so') }}
),

conversion AS (
    SELECT 
        record_id AS idfb,
        channel_id AS mgntid
    FROM {{ ref('fishbowl_plugininfo') }}
    WHERE related_table_name = 'SOItem'
),

conversion_product AS (
    SELECT 
        record_id AS produtofish,
        channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }}
    WHERE related_table_name = 'Product'
),

conversion_so AS (
    SELECT 
        record_id AS produtofish,
        channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }}
    WHERE related_table_name = 'SO'
),

cost_fishbowl AS (
    SELECT
        soi.total_cost,
        mi.magento_order_item_identity,
        cp.produto_magento AS id_produto_magento,
        conv.mgntid AS sales_order_item_magento,
        soi.so_item_id,
        soi.so_id AS order_fishbowl_id
    FROM {{ ref('fishbowl_soitem') }} soi
    LEFT JOIN conversion conv ON soi.so_item_id = conv.idfb
    LEFT JOIN conversion_product cp ON soi.product_id = cp.produtofish
    LEFT JOIN magento_identities mi ON soi.so_id = mi.code
),

sales AS (
    SELECT 
        soi.so_item_id,
        soi.so_id,
        soi.product_id,
        soi.quantity_ordered,
        soi.unit_price,
        soi.total_price,
        soi.total_cost,
        soi.quantity_shipped,
        prod.sku,
        prod.product_description,
        prod.product_price,
        shp.ship_date,
        shp.tracking_number,
        shpct.carton_weight,
        shpct.freight_amount
    FROM {{ ref('fishbowl_soitem') }} soi
    LEFT JOIN {{ ref('fishbowl_product') }} prod ON soi.product_id = prod.product_id
    LEFT JOIN {{ ref('fishbowl_ship') }} shp ON soi.so_id = shp.so_id
    LEFT JOIN {{ ref('fishbowl_shipcarton') }} shpct ON shp.shipment_id = shpct.shipment_id
)

SELECT 
    sales.so_item_id,
    sales.so_id,
    sales.product_id,
    sales.sku,
    sales.product_description,
    sales.product_price,
    sales.quantity_ordered,
    sales.quantity_shipped,
    sales.unit_price,
    sales.total_price,
    sales.total_cost,
    sales.ship_date,
    sales.tracking_number,
    sales.carton_weight,
    sales.freight_amount,
    cf.magento_order_item_identity,
    cf.id_produto_magento,
    cf.sales_order_item_magento
FROM 
    sales
LEFT JOIN 
    cost_fishbowl cf ON sales.so_item_id = cf.so_item_id
