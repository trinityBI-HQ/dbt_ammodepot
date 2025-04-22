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
        convert_timezone(
          'UTC',
          'America/New_York',
          z.item_created_at::timestamp
        )                                           AS created_at,
        z.product_id,
        z.order_id,
        z.quantity_ordered                              AS qty_ordered,
        z.discount_amount,
        CAST(z.product_id AS VARCHAR)
          || '@'
          || CAST(z.order_id    AS VARCHAR)        AS chave,
        COALESCE(
          u.cost,
          d.cost,
          a2.cost,
          u.averageweightedcost * z.quantity_ordered,
          d.averageweightedcost * z.quantity_ordered,
          a2.averageweightedcost * z.quantity_ordered
        )                                           AS cost,
        COALESCE(
          u.averageweightedcost,
          d.averageweightedcost,
          a2.averageweightedcost
        )                                           AS averageweightedcost,
        z.tax_amount,
        (z.row_total
          - COALESCE(z.amount_refunded,0)
          - COALESCE(z.discount_amount,0)
        )                                           AS row_total,
        o.order_increment_id,
        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code    AS country,
        a.region,
        a.city,
        a.street_address  AS street,
        a.phone_number    AS telephone,
        o.customer_firstname
          || ' '
          || o.customer_lastname                AS customer_name,
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
        o.customer_id,
        z.vendor_id
    FROM {{ ref('magento_sales_order_item') }}        AS z
    LEFT JOIN {{ ref('magento_sales_order') }}         AS o
      ON z.order_id           = o.order_id
    LEFT JOIN {{ ref('magento_sales_order_address') }} AS a
      ON o.billing_address_id = a.order_id
    LEFT JOIN cost_unique_magento_id                   AS u
      ON z.order_item_id      = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product        AS d
      ON z.order_item_id      = d.id_magento
      AND z.product_id        = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg            AS a2
      ON z.order_item_id      = a2.id_magento
    LEFT JOIN status_processing_costs                  AS sp
      ON z.order_id           = sp.order_id
),

-- Last‐day cost across all interactions
last_day_cost_all AS (
    SELECT
        ib.product_id,
        MAX(ib.created_at)     AS last_scheduled_date
    FROM interaction_base AS ib
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
    GROUP BY ib.product_id
),

filtered_cost_all_prep AS (
    SELECT
        ib.product_id,
        ib.cost,
        ib.qty_ordered        AS qty,
        ib.created_at
    FROM interaction_base AS ib
    JOIN last_day_cost_all   AS ld
      ON ib.product_id = ld.product_id
     AND ib.created_at = ld.last_scheduled_date
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
),

filtered_cost_all AS (
    SELECT
        fcap.product_id,
        SUM(fcap.cost)::numeric
          / NULLIF(SUM(fcap.qty),0)         AS avg_unit_cost,
        fcap.created_at
    FROM filtered_cost_all_prep AS fcap
    GROUP BY fcap.product_id, fcap.created_at
),

-- UPS invoicing from Magento source
ups_shipment_cost AS (
    SELECT
        tracking_number,
        SUM(net_amount)          AS net_amount
    FROM {{ source('magento','ups_invoice') }}
    GROUP BY tracking_number
),

-- Fishbowl shipment costs enriched with UPS
fishbowl_shipment_costs AS (
    SELECT
        fs.sales_order_id         AS soid,
        COALESCE(SUM(usc.net_amount), SUM(sc.freight_amount)) AS freight_amount,
        SUM(sc.freight_weight)    AS freight_weight,
        AVG(fs.carrier_service_id) AS carrier_service_id,
        SUM(usc.net_amount)       AS amount_ups,
        COUNT(sc.tracking_number) AS package_count
    FROM {{ ref('fishbowl_ship') }}        AS fs
    LEFT JOIN {{ ref('fishbowl_shipcarton') }} AS sc ON fs.shipment_id         = sc.shipment_id
    LEFT JOIN ups_shipment_cost              AS usc ON sc.tracking_number = usc.tracking_number
    GROUP BY fs.sales_order_id
),

-- Bring Fishbowl freight into Magento context
magento_freight_info AS (
    SELECT
        pc.produto_magento        AS order_magento,
        AVG(fb2.freight_amount)    AS freight_amount,
        AVG(fb2.freight_weight)    AS freight_weight,
        AVG(fb2.carrier_service_id) AS carrier_service_id
    FROM {{ ref('fishbowl_so') }}            AS fb
    LEFT JOIN fishbowl_shipment_costs       AS fb2 ON fb.sales_order_id = fb2.soid
    LEFT JOIN conversion_so                  AS pc  ON fb.sales_order_id = pc.produtofish
    GROUP BY pc.produto_magento
),

-- Allocate freight by weight inside each Magento order
magento_order_items_for_freight AS (
    SELECT
        m.item_weight                                            AS weight,
        m.order_id                                               AS order_id,
        m.sku,
        m.product_id,
        m.quantity_ordered                                       AS qty_ordered,

        -- evita divisão por zero e replica o div0 original
        CASE
            WHEN (m.row_total
                  - COALESCE(m.amount_refunded, 0)
                  - COALESCE(m.discount_amount, 0)
                  + COALESCE(m.discount_refunded, 0)
                 ) = 0
            THEN 0
            ELSE (m.quantity_ordered * m.row_total)
                 / NULLIF(
                     (m.row_total
                      - COALESCE(m.amount_refunded, 0)
                      - COALESCE(m.discount_amount, 0)
                      + COALESCE(m.discount_refunded, 0)
                     ), 0
                   )
        END                                                      AS test,

        -- recalcula o row_total limpando reembolsos e descontos
        (m.row_total
           - COALESCE(m.amount_refunded, 0)
           - COALESCE(m.discount_amount, 0)
           + COALESCE(m.discount_refunded, 0)
        )                                                         AS row_total
    FROM {{ ref('magento_sales_order_item') }}    AS m
    LEFT JOIN {{ ref('magento_catalog_product_entity') }} AS ct
      ON m.product_id = ct.product_entity_id
    WHERE 
      -- garante que não haja divisão por zero
      (m.row_total
         - COALESCE(m.amount_refunded, 0)
         - COALESCE(m.discount_amount, 0)
         + COALESCE(m.discount_refunded, 0)
      ) <> 0
      -- filtra SKUs “parcel defender”
      AND ct.sku NOT ILIKE '%parceldefender%'
),

magento_order_weight AS (
    SELECT
        order_id,
        SUM(weight)       AS total_weight,
        COUNT(product_id) AS product_count
    FROM magento_order_items_for_freight
    GROUP BY order_id
),
skubase AS (
  SELECT
    -- dates & times
    ib.created_at::date                                    AS created_at,
    ib.created_at                                          AS timedate,
    date_trunc('hour', ib.created_at)                      AS tiniciodahora_copiar,

    -- identifiers
    ib.product_id,
    ib.order_id,

    -- quantity ordered, safe‑guarding against divide‑by‑zero
    CASE
      WHEN (ib.row_total
            - COALESCE(ib.amount_refunded,0)
            - COALESCE(ib.discount_amount,0)
            + COALESCE(ib.discount_refunded,0)
           ) = 0
      THEN 0
      ELSE (ib.qty_ordered * ib.row_total)
           / NULLIF(
               (ib.row_total
                - COALESCE(ib.amount_refunded,0)
                - COALESCE(ib.discount_amount,0)
                + COALESCE(ib.discount_refunded,0)
               ), 0
             )
    END                                                     AS qty_ordered,
    ib.qty_ordered                                         AS ordered,

    -- discount & key
    ib.discount_invoiced                                   AS discount_invoiced,
    ib.product_id::varchar || '@' || ib.order_id::varchar AS chave,

    -- cost fields
    CASE WHEN ib.qty_ordered > 0 THEN ib.cost ELSE NULL END AS cost,
    ib.averageweightedcost                                 AS average_weighted_cost,

    -- financials
    ib.tax_amount                                          AS tax_amount,
    ib.row_total                                           AS row_total,

    -- order metadata
    ib.increment_id                                        AS increment_id,
    ib.billing_address_id                                  AS billing_address_id,
    ib.customer_email                                      AS customer_email,

    -- address
    ib.postcode                                            AS postcode,
    ib.country                                             AS country,
    ib.region                                              AS region,
    ib.city                                                AS city,
    ib.street                                              AS street,
    ib.telephone                                           AS telephone,

    -- customer
    ib.customer_name                                       AS customer_name,

    -- item/status
    ib.id                                                  AS id,
    UPPER(ib.status)                                       AS status,

    -- order‑level costs
    ib.cost                                                AS order_cost,
    ib.fishbowl_registeredcost                             AS fishbowl_registered_cost,

    -- store
    ib.store_id                                            AS store_id,
    ib.store_name                                          AS store_name,

    -- weight & freight allocation
    ib.weight                                              AS weight,
    CASE
      WHEN mow.total_weight = 0 THEN 0
      ELSE ib.weight::numeric / mow.total_weight
    END                                                     AS percentage,
    mow.total_weight                                       AS weightorder,

    -- freight revenue & cost by weight share
    CASE
      WHEN mow.total_weight = 0 THEN 0
      ELSE (ib.weight::numeric / mow.total_weight) * mos.freight_amount
    END                                                     AS freight_revenue,
    CASE
      WHEN mow.total_weight = 0 THEN 0
      ELSE (ib.weight::numeric / mow.total_weight) * mos.freight_amount
    END                                                     AS freight_cost,

    -- part sales & conversion
    ps.part_qty_sold                                       AS part_qty_sold,
    COALESCE(ps.conversion,1)                              AS conversion,

    -- hour‑of‑day
    date_trunc('hour', ib.created_at)::time                AS tiniciodahora,
    ib.created_at                                          AS trickat,

    -- misc
    ib.product_options,
    ib.product_type,
    ib.parent_item_id,
    ib.testsku,
    ib.vendor,
    ib.customer_id

  FROM interaction_base        AS ib
  LEFT JOIN magento_order_shipping_agg  AS mos ON ib.order_id = mos.order_id
  LEFT JOIN magento_order_weight        AS mow ON ib.order_id = mow.order_id
  LEFT JOIN magento_product_sales_uom   AS ps  ON ib.id       = ps.order_item_id
),

final AS (
  SELECT
    sb.created_at,
    sb.timedate,
    sb.product_id,
    sb.order_id,
    sb.qty_ordered,
    sb.row_total,
    COALESCE(
      NULLIF(sb.cost,0),
      fca.avg_unit_cost * sb.qty_ordered
    )                                                      AS calculated_cost,
    sb.chave                                               AS chave,
    sb.testsku                                             AS sku,
    sb.customer_email,
    sb.postcode,
    sb.country,
    sb.region,
    sb.city,
    sb.street                                              AS street_address,
    sb.telephone                                           AS phone_number,
    sb.customer_name,
    sb.store_id,
    sb.status                                              AS order_status,
    sb.vendor,
    sb.customer_id,
    sb.part_qty_sold,
    sb.conversion
  FROM skubase                     AS sb
  LEFT JOIN filtered_cost_all      AS fca
    ON sb.product_id = fca.product_id
  WHERE sb.product_type <> 'configurable'
)

SELECT * FROM final
