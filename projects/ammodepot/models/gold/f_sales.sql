{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

-- Start Code Conversions Fishbowl → Magento
WITH magento_identities AS (
    SELECT
        NULLIF(
          json_extract_path_text(a.custom_fields, 'Magento Order Identity 1'),
          ''
        ) AS magento_order_item_identity,
        a.sales_order_id AS code
    FROM {{ ref('fishbowl_so') }} AS a
    WHERE json_extract_path_text(a.custom_fields, 'Magento Order Identity 1') IS NOT NULL
),

conversion_soitem AS (
    SELECT
        f.record_id AS idfb,
        f.channel_id AS mgntid
    FROM {{ ref('fishbowl_plugininfo') }} AS f
    WHERE f.related_table_name = 'SOItem'
),

conversion_product AS (
    SELECT
        f.record_id  AS produtofish,
        f.channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} AS f
    WHERE f.related_table_name = 'Product'
),

conversion_so AS (
    SELECT
        f.record_id  AS produtofish,
        f.channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} AS f
    WHERE f.related_table_name = 'SO'
),

-- Real & Estimated Cost Segregation
cost_test AS (
    SELECT
        z.total_cost                  AS cost,
        m.magento_order_item_identity AS magento_order,
        t.produto_magento             AS id_produto_magento,
        child.mgntid                  AS id_magento,
        z.so_item_id                  AS id_soitem,
        z.sales_order_id              AS order_fishbowl_id
    FROM {{ ref('fishbowl_soitem') }} AS z
    LEFT JOIN conversion_soitem   AS child ON z.so_item_id     = child.idfb
    LEFT JOIN conversion_product  AS t     ON z.product_id     = t.produtofish
    LEFT JOIN magento_identities  AS m     ON z.sales_order_id = m.code
),

cost_aggregation AS (
    SELECT
        id_magento            AS id,
        COUNT(*)              AS count_of_id_magento,
        MAX(order_fishbowl_id) AS order_fb
    FROM cost_test
    GROUP BY id_magento
),

-- UOM Conversion to base
uom_to_base AS (
    SELECT
        from_uom_id      AS fromuomid,
        multiply_factor  AS multiply,
        to_uom_id        AS touomid
    FROM {{ ref('fishbowl_uomconversion') }}
    WHERE to_uom_id = 1
),

-- Fishbowl product average cost
product_avg_cost AS (
    SELECT
        p.product_id                                  AS id_produto,
        u.multiply                                    AS conversion,
        COALESCE(c.average_cost * u.multiply, c.average_cost)
                                                     AS averagecost,
        c.average_cost                                AS costnoconversion
    FROM {{ ref('fishbowl_product') }}     AS p
    LEFT JOIN {{ ref('fishbowl_partcost') }} AS c ON p.part_id  = c.part_id
    LEFT JOIN uom_to_base                       AS u ON p.uom_id  = u.fromuomid
),

-- Kit relationships
object_kit AS (
    SELECT
        object1_record_id    AS recordid1,
        object2_record_id    AS recordid2,
        relationship_type_id AS typeid
    FROM {{ ref('fishbowl_objecttoobject') }}
    WHERE relationship_type_id = 30
),

kit_cost_aggregation AS (
    SELECT
        SUM(s.total_cost)       AS cost,
        k.recordid2             AS kitid,
        SUM(a.averagecost)      AS costprocessing,
        MAX(s.quantity_ordered) AS maxqtytest
    FROM {{ ref('fishbowl_soitem') }} AS s
    LEFT JOIN product_avg_cost          AS a ON s.product_id = a.id_produto
    LEFT JOIN object_kit                AS k ON s.so_item_id  = k.recordid1
    WHERE s.item_type_id = 10
      AND s.product_description NOT ILIKE '%POLLYAMOBAG%'
    GROUP BY k.recordid2
),

-- Base Fishbowl cost linked to Magento IDs
cost_fishbowl_base AS (
    SELECT
        CASE WHEN s.total_cost = 0 THEN k.cost ELSE s.total_cost END AS cost,
        m.magento_order_item_identity                             AS magento_order,
        pr.produto_magento                                        AS id_produto_magento,
        child.mgntid                                              AS id_magento,
        s.so_item_id,
        s.sales_order_id,
        ca.count_of_id_magento,
        s.product_id                                              AS id_produto_fishbowl,
        p.is_kit                                                  AS bundle,
        COALESCE(k.costprocessing, a.averagecost)                 AS averageweightedcost,
        s.scheduled_fulfillment_date                              AS scheduled_fulfillment_date,
        s.quantity_fulfilled                                      AS qty
    FROM {{ ref('fishbowl_soitem') }} AS s
    LEFT JOIN conversion_soitem         AS child ON s.so_item_id       = child.idfb
    LEFT JOIN product_avg_cost          AS a     ON s.product_id       = a.id_produto
    LEFT JOIN conversion_product        AS pr    ON s.product_id       = pr.produtofish
    LEFT JOIN magento_identities        AS m     ON s.sales_order_id   = m.code
    LEFT JOIN cost_aggregation          AS ca    ON child.mgntid        = ca.id
    LEFT JOIN {{ ref('fishbowl_product') }}      AS p     ON s.product_id       = p.product_id
    LEFT JOIN kit_cost_aggregation      AS k     ON s.so_item_id       = k.kitid
),

-- Last‐day cost per product
last_day_cost_fishbowl AS (
    SELECT
        id_produto_fishbowl             AS product_id,
        MAX(scheduled_fulfillment_date) AS last_scheduled_date
    FROM cost_fishbowl_base
    WHERE cost > 0
    GROUP BY id_produto_fishbowl
),

filtered_cost_fishbowl AS (
    SELECT
        f.id_produto_fishbowl         AS product_id,
        AVG(f.cost / NULLIF(f.qty,0)) AS cost
    FROM cost_fishbowl_base AS f
    JOIN last_day_cost_fishbowl     AS ld
      ON f.id_produto_fishbowl         = ld.product_id
     AND f.scheduled_fulfillment_date = ld.last_scheduled_date
    WHERE f.cost > 0
    GROUP BY f.id_produto_fishbowl
),

-- Final Fishbowl cost
cost_fishbowl_final AS (
    SELECT
        COALESCE(NULLIF(b.cost,0), NULLIF(k.cost,0), fc.cost * b.qty) AS cost,
        k.cost                            AS costbundle,
        fc.cost                           AS costfiltered,
        b.id_produto_magento,
        b.id_magento,
        b.so_item_id,
        b.sales_order_id,
        b.count_of_id_magento,
        b.id_produto_fishbowl,
        b.bundle,
        b.averageweightedcost,
        b.scheduled_fulfillment_date,
        b.qty
    FROM cost_fishbowl_base      AS b
    LEFT JOIN kit_cost_aggregation AS k ON b.so_item_id        = k.kitid
    LEFT JOIN filtered_cost_fishbowl AS fc ON b.id_produto_fishbowl = fc.product_id
),

-- Costs where Magento ID is unique
cost_unique_magento_id AS (
    SELECT f.*
    FROM cost_fishbowl_final   AS f
    JOIN cost_aggregation      AS ca ON f.id_magento      = ca.id
    WHERE ca.count_of_id_magento = 1
),

-- Average costs when Magento ID appears multiple times
cost_duplicate_magento_id_product AS (
    SELECT
        AVG(f.cost)                AS cost,
        f.id_magento               AS id_magento,
        AVG(f.averageweightedcost) AS averageweightedcost,
        f.id_produto_magento       AS id_produto_magento
    FROM cost_fishbowl_final    AS f
    JOIN cost_aggregation       AS ca ON f.id_magento      = ca.id
    WHERE ca.count_of_id_magento > 1
    GROUP BY f.id_magento, f.id_produto_magento
),

-- Further average for duplicated IDs, filtering out zero‐total orders
cost_duplicate_magento_id_avg AS (
    SELECT
        AVG(d.cost)                AS cost,
        AVG(d.averageweightedcost) AS averageweightedcost,
        d.id_magento
    FROM cost_duplicate_magento_id_product AS d
    JOIN {{ ref('magento_sales_order_item') }} AS m
      ON d.id_magento = m.order_item_id
    WHERE m.row_total <> 0
    GROUP BY d.id_magento
),

-- Aggregate Fishbowl costs per Magento order
status_processing_costs AS (
    SELECT
        m.order_id,
        SUM(COALESCE(u.cost, d.cost)) AS cost,
        SUM(COALESCE(u.averageweightedcost, d.averageweightedcost)) AS cost_average_order
    FROM {{ ref('magento_sales_order_item') }} AS m
    LEFT JOIN cost_unique_magento_id            AS u  ON m.order_item_id = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product AS d  ON m.order_item_id = d.id_magento
                                                   AND m.product_id    = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg     AS a2 ON m.order_item_id = a2.id_magento
    GROUP BY m.order_id
),

-- First interaction: join Magento & Fishbowl costs
interaction_base AS (
    SELECT
        -- Data/hora convertida
        convert_timezone(
          'UTC',
          'America/New_York',
          z.item_created_at::timestamp
        )                                                   AS created_at,

        -- IDs e quantidades
        z.product_id,
        z.order_id,
        z.quantity_ordered                                  AS qty_ordered,

        -- descontos
        z.discount_amount,
        z.discount_invoiced,  -- <--- adicionada

        -- Chave única de item
        CAST(z.product_id AS VARCHAR)
          || '@'
          || CAST(z.order_id    AS VARCHAR)               AS chave,

        -- Custo (Magento ou Fishbowl) e custo médio ponderado
        COALESCE(
          u.cost,
          d.cost,
          a2.cost,
          u.averageweightedcost * z.quantity_ordered,
          d.averageweightedcost * z.quantity_ordered,
          a2.averageweightedcost * z.quantity_ordered
        )                                                   AS cost,
        COALESCE(
          u.averageweightedcost,
          d.averageweightedcost,
          a2.averageweightedcost
        )                                                   AS averageweightedcost,

        -- Tributação
        z.tax_amount,
        (z.row_total - COALESCE(z.discount_amount, 0))      AS row_total,

        -- Alias padronizado de increment_id
        o.order_increment_id                                 AS increment_id,

        -- Endereço e cliente
        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code    AS country,
        a.region,
        a.city,
        a.street_address  AS street,
        a.phone_number    AS telephone,
        o.customer_firstname || ' ' || o.customer_lastname  AS customer_name,

        -- Metadados adicionais
        z.base_cost                                          AS cost_magento,
        z.order_item_id                                      AS id,
        o.order_status                                       AS status,
        sp.cost                                              AS fishbowl_registeredcost,
        z.store_id,
        o.store_name,
        z.item_weight                                        AS weight,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.sku                                                AS testsku,
        z.applied_rule_ids,
        o.customer_id,
        z.vendor_id
    FROM {{ ref('magento_sales_order_item') }}        AS z
    LEFT JOIN {{ ref('magento_sales_order') }}         AS o ON z.order_id           = o.order_id
    LEFT JOIN {{ ref('magento_sales_order_address') }} AS a ON o.billing_address_id = a.order_id
    LEFT JOIN cost_unique_magento_id                   AS u ON z.order_item_id      = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product        AS d ON z.order_item_id      = d.id_magento
                                                         AND z.product_id        = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg            AS a2 ON z.order_item_id      = a2.id_magento
    LEFT JOIN status_processing_costs                  AS sp ON z.order_id           = sp.order_id
),

-- Pega a última data de custo por produto
last_day_cost_all AS (
    SELECT
        ib.product_id,
        MAX(ib.created_at)     AS last_scheduled_date
    FROM interaction_base AS ib
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
    GROUP BY ib.product_id
),

-- Filtra somente o custo daquele último dia
filtered_cost_all_prep AS (
    SELECT
        ib.product_id,
        ib.cost,
        ib.qty_ordered         AS qty,
        ib.created_at
    FROM interaction_base AS ib
    JOIN last_day_cost_all   AS ld
      ON ib.product_id = ld.product_id
     AND ib.created_at = ld.last_scheduled_date
),

filtered_cost_all AS (
    SELECT
        product_id,
        cost,
        qty
    FROM filtered_cost_all_prep
),
-- UPS shipment costs (Magento source)
ups_shipment_cost AS (
    SELECT
        tracking_number,
        SUM(net_amount)          AS net_amount
    FROM {{ source('magento', 'ups_invoice') }}
    GROUP BY tracking_number
),

-- Fishbowl shipment costs enriched with UPS
fishbowl_shipment_costs AS (
    SELECT
        fs.sales_order_id                                         AS soid,
        COALESCE(SUM(usc.net_amount), SUM(sc.freight_amount))     AS freight_amount,
        SUM(sc.freight_weight)                                    AS freight_weight,
        AVG(fs.carrier_service_id)                                AS carrier_service_id,
        SUM(usc.net_amount)                                       AS amount_ups
    FROM {{ ref('fishbowl_ship') }}            AS fs
    LEFT JOIN {{ ref('fishbowl_shipcarton') }} AS sc  
      ON fs.shipment_id = sc.shipment_id
    LEFT JOIN ups_shipment_cost               AS usc 
      ON sc.tracking_number = usc.tracking_number
    GROUP BY fs.sales_order_id
),

-- Bring Fishbowl freight into Magento context
magento_freight_info AS (
    SELECT
        pc.produto_magento        AS order_magento,
        AVG(fb2.freight_amount)   AS freight_amount,
        AVG(fb2.freight_weight)   AS freight_weight,
        AVG(fb2.carrier_service_id) AS carrier_service_id
    FROM {{ ref('fishbowl_so') }}            AS fb
    LEFT JOIN fishbowl_shipment_costs       AS fb2 ON fb.sales_order_id = fb2.soid
    LEFT JOIN conversion_so                  AS pc  ON fb.sales_order_id = pc.produtofish
    GROUP BY pc.produto_magento
),

-- Allocate freight by weight inside each Magento order
magento_order_items_for_freight AS (
    SELECT
        m.item_weight        AS weight,
        m.order_id           AS order_id,
        m.sku,
        m.product_id,
        m.quantity_ordered   AS qty_ordered
    FROM {{ ref('magento_sales_order_item') }}  AS m
),

-- Sum total weight per order
magento_order_weight AS (
    SELECT
        order_id,
        SUM(weight)       AS total_weight,
        COUNT(product_id) AS product_count
    FROM magento_order_items_for_freight
    GROUP BY order_id
),

-- Allocate shipping cost per order
magento_order_shipping_agg AS (
    SELECT
        ms.order_id,
        SUM(ms.shipping_amount)               AS shipping_amount,
        SUM(ms.base_shipping_amount)          AS base_shipping_amount,
        SUM(ms.base_shipping_discount_amount) AS base_shipping_discount_amount,
        SUM(ms.base_shipping_refunded)        AS base_shipping_refunded,
        SUM(ms.base_shipping_tax_amount)      AS base_shipping_tax_amount,
        SUM(ms.base_shipping_tax_refunded)    AS base_shipping_tax_refunded,
        SUM(
          COALESCE(ms.base_shipping_amount, 0)
          - COALESCE(ms.base_shipping_tax_amount, 0)
          - COALESCE(ms.base_shipping_refunded, 0)
          + COALESCE(ms.base_shipping_tax_refunded, 0)
        )                                      AS net_sales,
        mfi.freight_amount
    FROM {{ ref('magento_sales_order') }}     AS ms
    LEFT JOIN magento_freight_info           AS mfi
      ON ms.order_id = mfi.order_magento
    GROUP BY ms.order_id, mfi.freight_amount
),
-- Agrega vendas de peça para cálculo de conversão
product_sales AS (
    SELECT
        s.order_item_id                                                   AS item_id,
        SUM(s.quantity_ordered * COALESCE(uom.multiply_factor, 1))         AS part_qty_sold,
        AVG(COALESCE(uom.multiply_factor, 1))                              AS conversion
    FROM {{ ref('magento_sales_order_item') }}       AS s
    LEFT JOIN {{ ref('fishbowl_uomconversion') }}    AS uom
      ON s.product_id = uom.from_uom_id
     AND uom.to_uom_id = 1
    WHERE s.product_type <> 'bundle'
      AND s.row_total <> 0
    GROUP BY s.order_item_id
),

-- Base de fatos de SKU
skubase AS (
    SELECT
        ib.created_at::date                                    AS created_at,
        ib.created_at                                          AS timedate,
        date_trunc('hour', ib.created_at)                      AS tiniciodahora_copiar,

        ib.product_id,
        ib.order_id,

        CASE
          WHEN ib.row_total = 0 THEN 0
          ELSE ib.qty_ordered * ib.row_total
        END                                                     AS qty_ordered,

        ib.discount_invoiced                                   AS discount_invoiced,
        ib.chave,

        CASE WHEN ib.qty_ordered > 0 THEN ib.cost ELSE NULL END  AS cost,
        ib.averageweightedcost                                 AS average_weighted_cost,

        ib.tax_amount                                          AS tax_amount,
        ib.row_total                                           AS row_total,

        ib.increment_id                                        AS increment_id,
        ib.billing_address_id                                  AS billing_address_id,
        ib.customer_email                                      AS customer_email,

        ib.postcode,
        ib.country,
        ib.region,
        ib.city,
        ib.street,
        ib.telephone                                          AS phone_number,
        ib.customer_name,

        ib.cost_magento,
        ib.id                                                AS order_item_id,
        ib.status                                           AS order_status,
        ib.fishbowl_registeredcost,
        ib.store_id,
        ib.store_name,
        ib.weight,
        ib.product_options,
        ib.product_type,
        ib.parent_item_id,
        ib.testsku,
        ib.applied_rule_ids,
        ib.customer_id,

        -- renomea vendor_id para vendor para casar com o final
        ib.vendor_id                                         AS vendor
    FROM interaction_base AS ib
),


-- Monta o fato final juntando custos históricos e vendas de peça
final AS (
    SELECT
        sb.created_at,
        sb.timedate,
        sb.tiniciodahora_copiar      AS tiniciodahora,
        sb.product_id,
        sb.order_id,
        sb.qty_ordered,
        sb.discount_invoiced,
        sb.chave,
        sb.cost,
        sb.average_weighted_cost,
        sb.tax_amount,
        sb.row_total,
        sb.increment_id,
        sb.billing_address_id,
        sb.customer_email,
        sb.postcode,
        sb.country,
        sb.region,
        sb.city,
        sb.street,
        sb.phone_number,
        sb.customer_name,
        sb.store_id,
        sb.order_status,
        sb.vendor,
        sb.customer_id,

        fca.cost                   AS last_cost,
        fca.qty                    AS last_qty,

        ps.part_qty_sold,
        COALESCE(ps.conversion, 1) AS conversion

    FROM skubase                AS sb
    LEFT JOIN filtered_cost_all AS fca
      ON sb.product_id = fca.product_id
    LEFT JOIN product_sales    AS ps
      ON sb.order_item_id = ps.item_id

    WHERE sb.product_type <> 'configurable'
)

SELECT * FROM final