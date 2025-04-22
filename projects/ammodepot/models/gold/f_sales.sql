{{ config(materialized='table', schema='gold') }}

WITH fishbowl_so_identities AS (
    SELECT
        json_extract_path_text(a.custom_fields, 'Magento Order Identity 1') AS magento_order_item_identity,
        a.sales_order_id
    FROM {{ ref('fishbowl_so') }} a
    WHERE json_extract_path_text(a.custom_fields, 'Magento Order Identity 1') IS NOT NULL
),

plugin_conversion_soitem AS (
    SELECT f.record_id AS idfb, f.channel_id AS mgntid
    FROM {{ ref('fishbowl_plugininfo') }} f
    WHERE f.related_table_name = 'SOItem'
),

plugin_conversion_product AS (
    SELECT f.record_id AS produtofish, f.channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} f
    WHERE f.related_table_name = 'Product'
),

plugin_conversion_so AS (
    SELECT f.record_id AS produtofish, f.channel_id AS produto_magento
    FROM {{ ref('fishbowl_plugininfo') }} f
    WHERE f.related_table_name = 'SO'
),

cost_test AS (
    SELECT
        z.total_cost         AS cost,
        m.magento_order_item_identity AS magento_order,
        t.produto_magento    AS id_produto_magento,
        child.mgntid         AS id_magento,
        z.so_item_id,
        z.sales_order_id     AS order_fishbowl_id
    FROM {{ ref('fishbowl_soitem') }} z
    LEFT JOIN plugin_conversion_soitem    child ON z.so_item_id = child.idfb
    LEFT JOIN plugin_conversion_product  t     ON z.product_id = t.produtofish
    LEFT JOIN fishbowl_so_identities      m     ON z.sales_order_id = m.sales_order_id
),

cost_aggregation AS (
    SELECT
        id_magento        AS id,
        COUNT(*)          AS count_of_id_magento,
        MAX(order_fishbowl_id) AS order_fb
    FROM cost_test
    GROUP BY id_magento
),

fishbowl_uom_conversion_to_base AS (
    SELECT 
      from_uom_id     AS fromuomid, 
      multiply_factor AS multiply, 
      to_uom_id       AS touomid
    FROM {{ ref('fishbowl_uomconversion') }} u
    WHERE u.to_uom_id = 1
),


fishbowl_product_avg_cost AS (
    SELECT
        p.product_id     AS id_produto,
        u.multiply       AS conversion,
        COALESCE(c.average_cost * u.multiply, c.average_cost) AS averagecost,
        c.average_cost   AS costnoconversion
    FROM {{ ref('fishbowl_product') }} p
    LEFT JOIN {{ ref('fishbowl_partcost') }} c ON p.part_id = c.part_id
    LEFT JOIN fishbowl_uom_conversion_to_base u 
        ON p.uom_id = u.fromuomid
),

fishbowl_object_kit AS (
    SELECT
        object1_record_id   AS recordid1,
        object2_record_id   AS recordid2,
        relationship_type_id AS typeid
    FROM {{ ref('fishbowl_objecttoobject') }}
    WHERE relationship_type_id = 30
),

fishbowl_kit_cost_aggregation AS (
    SELECT
        SUM(s.total_cost)       AS cost,
        k.recordid2             AS kitid,
        SUM(a.averagecost)      AS costprocessing    
    FROM {{ ref('fishbowl_soitem') }} AS s
    LEFT JOIN fishbowl_product_avg_cost AS a
      ON s.product_id = a.id_produto
    LEFT JOIN fishbowl_object_kit       AS k
      ON s.so_item_id = k.recordid1
    WHERE s.item_type_id = 10
      AND s.product_description NOT ILIKE '%POLLYAMOBAG%'
    GROUP BY k.recordid2
),

cost_fishbowl_base AS (
    SELECT
        CASE WHEN s.total_cost = 0 THEN k.cost ELSE s.total_cost END AS cost,
        m.magento_order_item_identity AS magento_order,
        pr.produto_magento           AS id_produto_magento,
        child.mgntid                 AS id_magento,
        s.so_item_id,
        s.sales_order_id,
        ca.count_of_id_magento,
        s.product_id                AS id_produto_fishbowl,
        p.is_kit                    AS bundle,
        COALESCE(k.costprocessing, a.averagecost) AS averageweightedcost,
        s.scheduled_fulfillment_date,
        s.quantity_fulfilled        AS qty
    FROM {{ ref('fishbowl_soitem') }} s
    LEFT JOIN plugin_conversion_soitem        child ON s.so_item_id = child.idfb
    LEFT JOIN fishbowl_product_avg_cost       a     ON s.product_id = a.id_produto
    LEFT JOIN plugin_conversion_product       pr    ON s.product_id = pr.produtofish
    LEFT JOIN fishbowl_so_identities          m     ON s.sales_order_id = m.sales_order_id
    LEFT JOIN cost_aggregation                ca    ON child.mgntid = ca.id
    LEFT JOIN {{ ref('fishbowl_product') }}    p     ON s.product_id = p.product_id
    LEFT JOIN fishbowl_kit_cost_aggregation    k     ON s.so_item_id = k.kitid
),

last_day_cost_fishbowl AS (
    SELECT id_produto_fishbowl AS product_id,
           MAX(scheduled_fulfillment_date) AS last_scheduled_date
    FROM cost_fishbowl_base
    WHERE cost > 0
    GROUP BY id_produto_fishbowl
),

filtered_cost_fishbowl AS (
    SELECT f.id_produto_fishbowl AS product_id,
           AVG(f.cost / NULLIF(f.qty,0)) AS cost
    FROM cost_fishbowl_base f
    JOIN last_day_cost_fishbowl ld
      ON f.id_produto_fishbowl = ld.product_id
     AND f.scheduled_fulfillment_date = ld.last_scheduled_date
    WHERE f.cost > 0
    GROUP BY f.id_produto_fishbowl
),

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
    LEFT JOIN fishbowl_kit_cost_aggregation k ON b.so_item_id = k.kitid
    LEFT JOIN filtered_cost_fishbowl          fc ON b.id_produto_fishbowl = fc.product_id
),

cost_unique_magento_id AS (
    SELECT f.*
    FROM cost_fishbowl_final f
    JOIN cost_aggregation ca
      ON f.id_magento = ca.id
    WHERE ca.count_of_id_magento = 1
),

cost_duplicate_magento_id_product AS (
    SELECT
        AVG(f.cost)                AS cost,
        f.id_magento               AS id_magento,
        AVG(f.averageweightedcost) AS averageweightedcost,
        f.id_produto_magento       AS id_produto_magento
    FROM cost_fishbowl_final f
    JOIN cost_aggregation ca
      ON f.id_magento = ca.id
    WHERE ca.count_of_id_magento > 1
    GROUP BY f.id_magento, f.id_produto_magento
),

cost_duplicate_magento_id_avg AS (
    SELECT
        AVG(d.cost)                AS cost,
        AVG(d.averageweightedcost) AS averageweightedcost,
        d.id_magento               AS id_magento
    FROM cost_duplicate_magento_id_product d
    JOIN {{ ref('magento_sales_order_item') }} m
      ON d.id_magento = m.order_item_id
    WHERE m.row_total <> 0
    GROUP BY d.id_magento
),


status_processing_costs AS (
    SELECT
        m.order_id,
        SUM(
          COALESCE(u.cost,
                   d.cost,
                   a2.cost)
        ) AS cost,
        SUM(
          COALESCE(u.averageweightedcost,
                   d.averageweightedcost,
                   a2.averageweightedcost)
        ) AS cost_average_order
    FROM {{ ref('magento_sales_order_item') }} AS m
    LEFT JOIN cost_unique_magento_id               AS u  
      ON m.order_item_id = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product    AS d  
      ON m.order_item_id = d.id_magento
     AND m.product_id      = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg        AS a2 
      ON m.order_item_id = a2.id_magento
    GROUP BY m.order_id
),

interaction_base AS (
    SELECT
        -- Use o timestamp renomeado no silver
        z.item_created_at         AS created_at,

        -- Chaves
        z.product_id,
        z.order_id,
        z.qty_ordered             AS qty_ordered,

        -- Descontos e chaves
        z.discount_amount         AS discount_invoiced,
        CAST(z.product_id AS VARCHAR) || '@' || CAST(z.order_id AS VARCHAR) AS chave,

        -- Cálculo de custo
        COALESCE(
            u.cost,
            d.cost,
            a2.cost,
            u.averageweightedcost * z.qty_ordered,
            d.averageweightedcost * z.qty_ordered,
            a2.averageweightedcost * z.qty_ordered
        )                          AS cost,
        COALESCE(
            u.averageweightedcost,
            d.averageweightedcost,
            a2.averageweightedcost
        )                          AS averageweightedcost,

        -- Ajustes financeiros
         z.tax_amount,
        (
          z.row_total
          - COALESCE(z.amount_refunded, 0)
          - COALESCE(z.discount_amount, 0)
        ) AS row_total,

        -- Informações do pedido
        o.order_increment_id,
        o.billing_address_id,
        o.customer_email,
        a.postcode,
        a.country_code           AS country,
        a.region,
        a.city,
        a.street_address         AS street,
        a.phone_number           AS telephone,
        CONCAT(o.customer_firstname, ' ', o.customer_lastname) AS customer_name,

        -- Custo Magento e outros campos
        z.base_cost               AS cost_magento,
        z.order_item_id           AS id,
        o.order_status            AS status,
        sp.cost                   AS fishbowl_registeredcost,
        z.store_id,
        o.store_name,
        z.item_weight             AS weight,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.sku                     AS testsku,
        z.additional_data,
        z.applied_rule_ids,
        z.vendor,
        o.customer_id
    FROM {{ ref('magento_sales_order_item') }}           AS z
    LEFT JOIN {{ ref('magento_sales_order') }}            AS o  ON z.order_id            = o.order_id
    LEFT JOIN {{ ref('magento_sales_order_address') }}    AS a  ON o.billing_address_id  = a.order_address_id
    LEFT JOIN cost_unique_magento_id                      AS u  ON z.order_item_id      = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product           AS d  ON z.order_item_id      = d.id_magento
                                                       AND z.product_id          = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg               AS a2 ON z.order_item_id      = a2.id_magento
    LEFT JOIN status_processing_costs                     AS sp ON z.order_id           = sp.order_id
),




last_day_cost_all AS (
    SELECT
        ib.product_id,
        MAX(ib.created_at)        AS last_scheduled_date
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
      ON ib.product_id = ld.product_id
     AND ib.created_at   = ld.last_scheduled_date
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
),

filtered_cost_all AS (
    SELECT
        fcap.product_id,
        SUM(fcap.cost)          AS total_cost,
        SUM(fcap.qty)           AS total_qty,
        DIV0(SUM(fcap.cost), SUM(fcap.qty)) AS avg_unit_cost,
        fcap.created_at
    FROM filtered_cost_all_prep fcap
    GROUP BY fcap.product_id, fcap.created_at
)

SELECT
    ib.created_at,
    ib.product_id,
    ib.order_id,
    ib.qty_ordered,
    ib.row_total,
    COALESCE(NULLIF(ib.cost,0), fca.avg_unit_cost * ib.qty_ordered) AS calculated_cost,
    ib.testsku        AS sku,
    ib.customer_email,
    ib.postcode,
    ib.country,
    ib.region,
    ib.city,
    ib.street        AS street_address,
    ib.telephone     AS phone_number,
    ib.customer_name,
    ib.store_id,
    ib.status        AS order_status,
    ib.vendor,
    ib.customer_id
FROM interaction_base ib
LEFT JOIN filtered_cost_all fca
  ON ib.product_id = fca.product_id
WHERE ib.product_type <> 'configurable'
