{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

-- Start Code Conversions Fishbowl → Magento
WITH magento_identities AS (
    SELECT
        NULLIF(json_extract_path_text(a.custom_fields, 'Magento Order Identity 1'), '') AS magento_order_item_identity,
        a.sales_order_id AS code
    FROM {{ ref('fishbowl_so') }} a
    WHERE json_extract_path_text(a.custom_fields, 'Magento Order Identity 1') IS NOT NULL
),

conversion_soitem AS (
    SELECT
        f.record_id AS idfb,
        f.channel_id AS mgntid
    FROM {{ ref('fishbowl_plugininfo') }} f
    WHERE f.related_table_name = 'SOItem'
),

conversion_product AS (
    SELECT
        f.record_id     AS produtofish,
        f.channel_id    AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} f
    WHERE f.related_table_name = 'Product'
),

conversion_so AS (
    SELECT
        f.record_id     AS produtofish,
        f.channel_id    AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} f
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
    FROM {{ ref('fishbowl_soitem') }} z
    LEFT JOIN conversion_soitem   child ON z.so_item_id       = child.idfb
    LEFT JOIN conversion_product  t     ON z.product_id       = t.produtofish
    LEFT JOIN magento_identities  m     ON z.sales_order_id   = m.code
),

cost_aggregation AS (
    SELECT
        id_magento           AS id,
        COUNT(*)             AS count_of_id_magento,
        MAX(order_fishbowl_id) AS order_fb
    FROM cost_test
    GROUP BY id_magento
),

-- UOM Conversion to base
uom_to_base AS (
    SELECT
        from_uom_id  AS fromuomid,
        multiply_factor     AS multiply,
        to_uom_id    AS touomid
    FROM {{ ref('fishbowl_uomconversion') }}
    WHERE to_uom_id = 1
),

-- Fishbowl product average cost
product_avg_cost AS (
    SELECT
        p.product_id                   AS id_produto,
        u.multiply                     AS conversion,
        COALESCE(c.average_cost * u.multiply, c.average_cost) AS averagecost,
        c.average_cost                 AS costnoconversion
    FROM {{ ref('fishbowl_product') }} p
    LEFT JOIN {{ ref('fishbowl_partcost') }}    c ON p.part_id = c.part_id
    LEFT JOIN uom_to_base                       u ON p.uom_id  = u.fromuomid
),

-- Kit relationships
object_kit AS (
    SELECT
        object1_record_id   AS recordid1,
        object2_record_id   AS recordid2,
        relationship_type_id AS typeid
    FROM {{ ref('fishbowl_objecttoobject') }}
    WHERE relationship_type_id = 30
),

kit_cost_aggregation AS (
    SELECT
        SUM(s.total_cost)        AS cost,
        k.recordid2              AS kitid,
        SUM(a.averagecost)       AS costprocessing,
        MAX(s.quantity_ordered)  AS maxqtytest
    FROM {{ ref('fishbowl_soitem') }}   s
    LEFT JOIN product_avg_cost         a ON s.product_id = a.id_produto
    LEFT JOIN object_kit               k ON s.so_item_id  = k.recordid1
    WHERE s.item_type_id = 10
      AND s.product_description NOT ILIKE '%POLLYAMOBAG%'
    GROUP BY k.recordid2
),

-- Base Fishbowl cost linked to Magento IDs
cost_fishbowl_base AS (
    SELECT
        CASE WHEN s.total_cost = 0 THEN k.cost ELSE s.total_cost END AS cost,
        m.magento_order_item_identity                              AS magento_order,
        pr.produto_magento                                         AS id_produto_magento,
        child.mgntid                                               AS id_magento,
        s.so_item_id,
        s.sales_order_id,
        ca.count_of_id_magento,
        s.product_id                                               AS id_produto_fishbowl,
        p.is_kit                                                   AS bundle,
        COALESCE(k.costprocessing, a.averagecost)                 AS averageweightedcost,
        s.scheduled_fulfillment_date,
        s.quantity_fulfilled                                       AS qty
    FROM {{ ref('fishbowl_soitem') }} s
    LEFT JOIN conversion_soitem          child ON s.so_item_id          = child.idfb
    LEFT JOIN product_avg_cost           a     ON s.product_id          = a.id_produto
    LEFT JOIN conversion_product         pr    ON s.product_id          = pr.produtofish
    LEFT JOIN magento_identities         m     ON s.sales_order_id      = m.code
    LEFT JOIN cost_aggregation           ca    ON child.mgntid           = ca.id
    LEFT JOIN {{ ref('fishbowl_product') }} p     ON s.product_id          = p.product_id
    LEFT JOIN kit_cost_aggregation       k     ON s.so_item_id          = k.kitid
),

-- Last‐day cost per product
last_day_cost_fishbowl AS (
    SELECT
        id_produto_fishbowl   AS product_id,
        MAX(scheduled_fulfillment_date) AS last_scheduled_date
    FROM cost_fishbowl_base
    WHERE cost > 0
    GROUP BY id_produto_fishbowl
),

filtered_cost_fishbowl AS (
    SELECT
        f.id_produto_fishbowl AS product_id,
        AVG(f.cost / NULLIF(f.qty,0)) AS cost
    FROM cost_fishbowl_base f
    JOIN last_day_cost_fishbowl ld
      ON f.id_produto_fishbowl = ld.product_id
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
    FROM cost_fishbowl_base b
    LEFT JOIN kit_cost_aggregation     k  ON b.so_item_id           = k.kitid
    LEFT JOIN filtered_cost_fishbowl   fc ON b.id_produto_fishbowl = fc.product_id
),

-- Costs where Magento ID is unique
cost_unique_magento_id AS (
    SELECT f.*
    FROM cost_fishbowl_final f
    JOIN cost_aggregation  ca ON f.id_magento = ca.id
    WHERE ca.count_of_id_magento = 1
),

-- Average costs when Magento ID appears multiple times
cost_duplicate_magento_id_product AS (
    SELECT
        AVG(f.cost)                AS cost,
        f.id_magento               AS id_magento,
        AVG(f.averageweightedcost) AS averageweightedcost,
        f.id_produto_magento       AS id_produto_magento
    FROM cost_fishbowl_final f
    JOIN cost_aggregation ca ON f.id_magento = ca.id
    WHERE ca.count_of_id_magento > 1
    GROUP BY f.id_magento, f.id_produto_magento
),

-- Further average for duplicated IDs, filtering out zero‐total orders
cost_duplicate_magento_id_avg AS (
    SELECT
        AVG(d.cost)                AS cost,
        AVG(d.averageweightedcost) AS averageweightedcost,
        d.id_magento
    FROM cost_duplicate_magento_id_product d
    JOIN {{ ref('magento_sales_order_item') }} m
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
    FROM {{ ref('magento_sales_order_item') }} m
    LEFT JOIN cost_unique_magento_id            u  ON m.order_item_id = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product d  ON m.order_item_id = d.id_magento
                                                   AND m.product_id    = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg       a2 ON m.order_item_id = a2.id_magento
    GROUP BY m.order_id
),


-- First interaction: join Magento & Fishbowl costs
interaction_base AS (
    SELECT
        -- convert from UTC into America/New_York
        convert_timezone(
          'UTC',
          'America/New_York',
          z.item_created_at::timestamp
        ) AS created_at,

        z.product_id,
        z.order_id,
        z.qty_ordered     AS qty_ordered,
        z.discount_amount,

        -- build a unique key
        CAST(z.product_id AS VARCHAR) || '@' || CAST(z.order_id AS VARCHAR) AS chave,

        -- pull in Fishbowl‑derived costs (unique vs duplicate logic)
        COALESCE(
          u.cost,
          d.cost,
          a2.cost,
          u.averageweightedcost * z.qty_ordered,
          d.averageweightedcost * z.qty_ordered,
          a2.averageweightedcost * z.qty_ordered
        ) AS cost,

        COALESCE(
          u.averageweightedcost,
          d.averageweightedcost,
          a2.averageweightedcost
        ) AS averageweightedcost,

        z.tax_amount,

        (
          z.row_total
          - COALESCE(z.amount_refunded, 0)
          - COALESCE(z.discount_amount, 0)
        ) AS row_total,

        o.order_increment_id,
        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code    AS country,
        a.region,
        a.city,
        a.street_address  AS street,
        a.phone_number    AS telephone,

        -- concatenando nome sem usar concat()
        o.customer_firstname
          || ' '
          || o.customer_lastname AS customer_name,

        z.base_cost       AS cost_magento,
        z.order_item_id   AS id,
        o.order_status    AS status,
        sp.cost           AS fishbowl_registeredcost,
        z.store_id,
        o.store_name,

        z.item_weight     AS weight,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.sku             AS testsku,
        z.applied_rule_ids,
        z.vendor,
        o.customer_id

    FROM {{ ref('magento_sales_order_item') }}        AS z
    LEFT JOIN {{ ref('magento_sales_order') }}         AS o ON z.order_id           = o.order_id
    LEFT JOIN {{ ref('magento_sales_order_address') }} AS a ON o.billing_address_id = a.order_address_id
    LEFT JOIN cost_unique_magento_id                   AS u ON z.order_item_id      = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product        AS d ON z.order_item_id      = d.id_magento
                                                          AND z.product_id         = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg            AS a2 ON z.order_item_id      = a2.id_magento
    LEFT JOIN status_processing_costs                  AS sp ON z.order_id           = sp.order_id
),

-- Last‐day cost across all interactions
last_day_cost_all AS (
    SELECT
        ib.product_id,
        MAX(ib.created_at) AS last_scheduled_date
    FROM interaction_base ib
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
    GROUP BY ib.product_id
),

filtered_cost_all_prep AS (
    SELECT
        ib.product_id,
        ib.cost,
        ib.qty_ordered AS qty,
        ib.created_at
    FROM interaction_base ib
    JOIN last_day_cost_all ld
      ON ib.product_id  = ld.product_id
     AND ib.created_at  = ld.last_scheduled_date
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
),

filtered_cost_all AS (
    SELECT
        fcap.product_id,
        DIV0(SUM(fcap.cost), SUM(fcap.qty)) AS avg_unit_cost,
        fcap.created_at
    FROM filtered_cost_all_prep fcap
    GROUP BY fcap.product_id, fcap.created_at
),

-- UPS invoicing from Magento source
ups_shipment_cost AS (
    SELECT
        tracking_number,
        SUM(net_amount) AS net_amount
    FROM {{ source('magento','ups_invoice') }}
    GROUP BY tracking_number
),

-- Fishbowl shipment costs enriched with UPS
fishbowl_shipment_costs AS (
    SELECT
        fs.sales_order_id       AS soid,
        COALESCE(SUM(usc.net_amount), SUM(sc.freight_amount))    AS freight_amount,
        SUM(sc.freight_weight)   AS freight_weight,
        AVG(fs.carrier_service_id) AS carrier_service_id,
        SUM(usc.net_amount)      AS amount_ups,
        COUNT(sc.tracking_number) AS package_count
    FROM {{ ref('fishbowl_ship') }}        fs
    LEFT JOIN {{ ref('fishbowl_shipcarton') }} sc ON fs.ship_id = sc.shipment_id
    LEFT JOIN ups_shipment_cost            usc ON sc.tracking_number = usc.tracking_number
    GROUP BY fs.sales_order_id
),

-- Bring Fishbowl freight into Magento context
magento_freight_info AS (
    SELECT
        pc.produto_magento AS order_magento,
        AVG(fb.freight_amount)  AS freight_amount,
        AVG(fb.freight_weight)  AS freight_weight,
        AVG(fb.carrier_service_id) AS carrier_service_id
    FROM {{ ref('fishbowl_so') }}    fb
    LEFT JOIN fishbowl_shipment_costs fb2 ON fb.sales_order_id = fb2.soid
    LEFT JOIN conversion_so            pc  ON fb.sales_order_id = pc.produtofish
    GROUP BY pc.produtofish
),

-- Allocate freight by weight inside each Magento order
magento_order_items_for_freight AS (
    SELECT
        m.order_item_id,
        m.order_id,
        m.product_id,
        m.quantity_ordered,
        (m.row_total
           - COALESCE(m.amount_refunded,0)
           - COALESCE(m.discount_amount,0)
           + COALESCE(m.discount_refunded,0)
        ) AS row_total,
        cp.sku
    FROM {{ ref('magento_sales_order_item') }} m
    JOIN {{ ref('magento_catalog_product_entity') }} cp ON m.product_id = cp.entity_id
    WHERE m.row_total <> 0
      AND cp.sku NOT ILIKE '%parceldefender%'
),

magento_order_weight AS (
    SELECT
        order_id,
        SUM(weight)       AS total_weight,
        COUNT(product_id) AS product_count
    FROM magento_order_items_for_freight
    GROUP BY order_id
),

magento_order_shipping_agg AS (
    SELECT
        ms.order_id,
        SUM(ms.shipping_amount)                AS shipping_amount,
        SUM(ms.base_shipping_amount)           AS base_shipping_amount,
        SUM(ms.base_shipping_discount_amount)  AS base_shipping_discount_amount,
        SUM(ms.base_shipping_refunded)         AS base_shipping_refunded,
        SUM(ms.base_shipping_tax_amount)       AS base_shipping_tax_amount,
        SUM(ms.base_shipping_tax_refunded)     AS base_shipping_tax_refunded,
        SUM(
          COALESCE(ms.base_shipping_amount,0)
          - COALESCE(ms.base_shipping_tax_amount,0)
          - COALESCE(ms.base_shipping_refunded,0)
          + COALESCE(ms.base_shipping_tax_refunded,0)
        ) AS net_sales,
        mfi.freight_amount
    FROM {{ ref('magento_sales_order') }} ms
    LEFT JOIN magento_freight_info mfi ON ms.order_id = mfi.order_magento
    GROUP BY ms.order_id, mfi.freight_amount
),

-- Final assembly
final AS (
    SELECT
        ib.created_at,
        ib.product_id,
        ib.order_id,
        ib.qty_ordered,
        ib.row_total,
        COALESCE(NULLIF(ib.cost,0), fca.avg_unit_cost * ib.qty_ordered) AS calculated_cost,
        ib.testsku          AS sku,
        ib.customer_email,
        ib.postcode,
        ib.country,
        ib.region,
        ib.city,
        ib.street          AS street_address,
        ib.telephone       AS phone_number,
        ib.customer_name,
        ib.store_id,
        ib.status         AS order_status,
        ib.vendor,
        ib.customer_id
    FROM interaction_base ib
    LEFT JOIN filtered_cost_all fca ON ib.product_id = fca.product_id
    WHERE ib.product_type <> 'configurable'
)

SELECT * FROM final
