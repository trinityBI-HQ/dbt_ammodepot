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
    FROM {{ ref('fishbowl_soitem_2') }} AS z
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
        COALESCE(
    NULLIF(SUM(CAST(s.total_cost AS DECIMAL(38,9))),0), 
    SUM(CAST(s.quantity_ordered AS DECIMAL(38,9)) * CAST(a.averagecost AS DECIMAL(38,9)))
) AS cost,
        k.recordid2             AS kitid,
        SUM(a.averagecost)      AS costprocessing,
        MAX(s.quantity_ordered) AS maxqtytest
    FROM {{ ref('fishbowl_soitem_2') }} AS s
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
    FROM {{ ref('fishbowl_soitem_2') }} AS s
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
    WHERE cost IS NOT NULL AND cost > 0
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
    WHERE f.cost IS NOT NULL AND f.cost > 0
    GROUP BY f.id_produto_fishbowl
),

-- Final Fishbowl cost
cost_fishbowl_final AS (
    SELECT
        COALESCE(NULLIF(b.total_cost,0), NULLIF(k.cost,0)) AS cost,
        b.total_cost as totalcost,
        k.cost                            AS costbundle,
        m.magento_order_item_identity     AS magento_order,
        fc.cost                           AS costfiltered,
        pr.produto_magento                AS id_produto_magento,
        child.mgntid                      AS id_magento,
        b.so_item_id,
        b.sales_order_id,
        ca.count_of_id_magento,
        b.product_id                                              AS id_produto_fishbowl,
        p.is_kit                                                  AS bundle,
        COALESCE(k.costprocessing, a.averagecost)                 AS averageweightedcost,
        b.scheduled_fulfillment_date                              AS scheduled_fulfillment_date,
        b.quantity_fulfilled                                      AS qty
    FROM {{ref('fishbowl_soitem_2')}}      AS b
    LEFT JOIN conversion_soitem         AS child ON b.so_item_id       = child.idfb
    LEFT JOIN product_avg_cost          AS a     ON b.product_id       = a.id_produto
    LEFT JOIN conversion_product        AS pr    ON b.product_id       = pr.produtofish
    LEFT JOIN magento_identities        AS m     ON b.sales_order_id   = m.code
    LEFT JOIN cost_aggregation          AS ca    ON child.mgntid       = ca.id
    LEFT JOIN {{ ref('fishbowl_product') }}      AS p     ON b.product_id       = p.product_id
    LEFT JOIN kit_cost_aggregation AS k ON b.so_item_id        = k.kitid
    LEFT JOIN filtered_cost_fishbowl AS fc ON b.product_id = fc.product_id
    
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
    JOIN {{ ref('magento_sales_order_item_2') }} AS m
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
    FROM {{ ref('magento_sales_order_item_2') }} AS m
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
        CASE 
        WHEN z.row_total <> 0 
            THEN (z.quantity_ordered * z.row_total) / z.row_total 
        ELSE 0 
        END AS qty_ordered,

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
        z.row_total
        - COALESCE(z.amount_refunded, 0)
        - COALESCE(z.discount_amount, 0)
        + COALESCE(z.discount_refunded, 0) AS row_total,

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
    FROM {{ ref('magento_sales_order_item_2') }}        AS z
    LEFT JOIN {{ ref('magento_sales_order_2') }}         AS o ON z.order_id           = o.order_id
    LEFT JOIN {{ ref('magento_sales_order_address') }} AS a ON o.billing_address_id = a.order_address_id
    LEFT JOIN cost_unique_magento_id                   AS u ON z.order_item_id      = u.id_magento
    LEFT JOIN cost_duplicate_magento_id_product        AS d ON z.order_item_id      = d.id_magento
                                                         AND z.product_id        = d.id_produto_magento
    LEFT JOIN cost_duplicate_magento_id_avg            AS a2 ON z.order_item_id      = a2.id_magento
    LEFT JOIN status_processing_costs                  AS sp ON z.order_id           = sp.order_id
),

-- Pega a última data de custo por produto
last_day_cost_all AS (
    SELECT
        CAST(ib.product_id AS VARCHAR) AS product_id,
        MAX(ib.created_at) AS last_scheduled_date
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
        ib.qty_ordered AS qty,
        ib.created_at
    FROM interaction_base AS ib
    JOIN last_day_cost_all AS ld
      ON CAST(ib.product_id AS VARCHAR) = ld.product_id
      AND ib.created_at = ld.last_scheduled_date
    WHERE ib.cost > 0
      AND ib.qty_ordered > 0
),

filtered_cost_all AS (
    SELECT
        product_id,
        SUM(cost) AS cost,
        SUM(qty) AS qty,
        created_at
    FROM filtered_cost_all_prep
    GROUP BY product_id, created_at
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
        SUM(usc.net_amount)                                       AS amount_ups,
        COUNT(sc.tracking_number)    AS packagenumb
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


-- Allocate freight by weight inside each Magento order (Simplified)
magento_order_items_for_freight AS (
     SELECT 
         m.item_weight                         AS weight
        ,m.order_id                            AS order_id
        ,m.sku
        ,m.product_id
        ,m.quantity_ordered                    AS qty_ordered
        ,CASE
            WHEN m.row_total = 0 THEN 0
            ELSE m.quantity_ordered            -- Simplificado: (qty * row_total)/row_total = qty
         END                                   AS test
        ,m.row_total
            - COALESCE(m.amount_refunded, 0)
            - COALESCE(m.discount_amount, 0)
            + COALESCE(m.discount_refunded, 0)
         AS row_total
    FROM {{ ref('magento_sales_order_item_2') }} AS m
    LEFT JOIN {{ ref('magento_catalog_product_entity') }} AS ct
        ON m.product_id = ct.product_entity_id
    WHERE (m.row_total 
            - COALESCE(m.amount_refunded, 0) 
            - COALESCE(m.discount_amount, 0) 
            + COALESCE(m.discount_refunded, 0)) <> 0
        AND m.quantity_ordered <> 0
        AND ct.sku NOT ILIKE '%parceldefender%'
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


-- Allocate shipping cost per order (Fixed operator issue)
magento_order_shipping_agg AS (
    SELECT
        ms.order_id,
        SUM(ms.shipping_amount)               AS shipping_amount,
        SUM(ms.base_shipping_amount)          AS base_shipping_amount,
        SUM(ms.base_shipping_canceled)        AS base_shipping_canceled,
        SUM(ms.base_shipping_canceled)        AS base_shipping_canceled,
        SUM(ms.base_shipping_discount_amount) AS base_shipping_discount_amount,
        SUM(ms.base_shipping_refunded)        AS base_shipping_refunded,
        SUM(ms.base_shipping_tax_amount)      AS base_shipping_tax_amount,
        SUM(ms.base_shipping_tax_refunded)    AS base_shipping_tax_refunded,
        SUM(
          COALESCE(ms.base_shipping_amount, 0)
          - COALESCE(ms.base_shipping_tax_amount, 0)
          - COALESCE(ms.base_shipping_refunded, 0)
          + COALESCE(ms.base_shipping_tax_refunded, 0)
        )   AS net_sales,
        SUM(mfi.freight_amount) AS freight_amount
    FROM {{ ref('magento_sales_order_2') }}     AS ms
    LEFT JOIN magento_freight_info           AS mfi
      ON ms.order_id = mfi.order_magento
    GROUP BY ms.order_id
),


-- Agrega vendas de peça para cálculo de conversão
product_sales AS (
    SELECT
        s.order_item_id                                                   AS item_id,
        SUM(s.quantity_ordered * COALESCE(uom.multiply_factor, 1))         AS part_qty_sold,
        AVG(COALESCE(uom.multiply_factor, 1))                              AS conversion,
        cpe.sku
     FROM {{ ref('magento_sales_order_item_2') }}       AS s   
    JOIN {{ ref('magento_sales_order_2')}}             AS o       ON  s.order_id = o.order_id
    JOIN {{ ref('magento_catalog_product_entity')}}  AS cpe     ON  s.product_id = cpe.product_entity_id
    JOIN {{ ref('fishbowl_product')}}                AS pr      ON  cpe.sku = pr.product_number
    JOIN {{ ref('fishbowl_part')}}                   AS p       ON  pr.part_id = p.part_id
    LEFT JOIN {{ ref('fishbowl_uomconversion') }}    AS uom     
      ON s.product_id = uom.from_uom_id
     AND uom.to_uom_id = 1
    WHERE s.product_type <> 'bundle'
      AND s.row_total <> 0
    GROUP BY s.order_item_id, cpe.sku

),

-- Calcular part_qty_sold em uma CTE separada
product_qty_sold AS (
    SELECT
        ps.item_id,
        ps.part_qty_sold,
        ps.item_id                                                   AS item_id,
        ps.sku
    FROM product_sales AS ps
),

-- Base de fatos de SKU (simplificada para evitar overflow, mantendo nomes originais)
skubase AS (
    SELECT
        ib.created_at::date                                AS created_at,
        ib.created_at                                      AS timedate,
        date_trunc('hour', ib.created_at)                  AS tiniciodahora_copiar,
        cast(date_trunc('HOUR', ib.created_at) as time )   AS tiniciodaHora,
        ib.product_id,
        ib.order_id,

        /* Quantidade usada pelo Snowflake (div0(qty_ordered*row_total,row_total))    */
        /* aqui basta proteger contra 0, mas o resultado é sempre qty_ordered        */
        CASE
            WHEN ib.row_total = 0 THEN 0
            ELSE ib.qty_ordered
        END                                               AS qty_ordered,

        ib.qty_ordered                                     AS ordered,          -- novo

        ib.discount_invoiced                               AS discount_invoiced,
        ib.chave,

        CASE WHEN ib.qty_ordered > 0 THEN ib.cost ELSE NULL END AS cost,
        ib.averageweightedcost                             AS average_weighted_cost,

        ib.tax_amount                                      AS tax_amount,
        ib.row_total                                       AS row_total,

        ib.increment_id,
        ib.billing_address_id,
        ib.customer_email,

        ib.postcode,
        ib.country,
        ib.region,
        ib.city,
        ib.street,
        ib.telephone                                       AS phone_number,
        ib.customer_name,

        ib.id                                              AS order_item_id,
        UPPER(ib.status)                                   AS order_status,     -- idem Snowflake
        ib.cost_magento,
        ib.fishbowl_registeredcost,
        ib.store_id,
        ib.store_name,
        ib.weight,

       
        mo.net_sales                                        AS frsales,           -- vendas líquidas do pedido
        mo.freight_amount                                  AS fcost,             -- custo total de frete do pedido
        mow.total_weight                                   AS weightorder,
        mow.product_count                                  AS products_in_order,

        /* % do peso da linha em relação ao pedido */
        ib.weight / NULLIF(mow.total_weight, 0)            AS percentage,

       
        /* Cálculo de freight_revenue simplificado mas mantendo a lógica original */
        CASE
            WHEN mow.total_weight IS NULL AND ib.testsku NOT ILIKE '%parceldefender%' THEN
                -- div0null( safe_qty_from_div0 * ty.netsales, ctm.products * safe_qty_from_div0 )
                ( (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END) * mo.net_sales )
                /
                NULLIF( (mow.product_count * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END)), 0)
            ELSE
                -- div0null( z.weight * safe_qty_from_div0 * ty.netsales, mow.total_weight * safe_qty_from_div0 )
                ( ib.weight * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END) * mo.net_sales )
                /
                NULLIF( (mow.total_weight * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END)), 0)
        END AS freight_revenue,
       
        /* Cálculo de freight_cost simplificado mas mantendo a lógica original */
        CASE
            WHEN mow.total_weight IS NULL AND ib.testsku NOT ILIKE '%parceldefender%' THEN
                -- div0null( safe_qty_from_div0, ctm.products * safe_qty_from_div0 ) * Freightamount
                (
                    (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END)
                    /
                    NULLIF( (mow.product_count * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END)), 0)
                ) * mo.freight_amount
            ELSE
                -- div0null( z.weight * safe_qty_from_div0, mow.total_weight * safe_qty_from_div0 ) * Freightamount
                (
                    (ib.weight * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END) )
                    /
                    NULLIF( (mow.total_weight * (CASE WHEN ib.row_total = 0 THEN 0 ELSE ib.qty_ordered END)), 0)
                ) * mo.freight_amount
        END AS freight_cost,                           
        
        -- Mantendo referência original, precisamos garantir que seja incluído corretamente
        ps.part_qty_sold,
        COALESCE(ps.conversion, 1)                        AS conversion,

        ib.product_options,
        ib.product_type,
        ib.parent_item_id,
        ib.testsku,
        ib.applied_rule_ids,
        ib.customer_id,
        ib.vendor_id                                      AS vendor             -- renomeado
    FROM interaction_base              AS ib
    LEFT JOIN magento_order_shipping_agg AS mo
           ON mo.order_id = ib.order_id
   
    LEFT JOIN product_sales            AS ps
           ON ps.item_id = ib.id
    LEFT JOIN magento_order_weight     AS mow
           ON mow.order_id = ib.order_id
),
-- Itens “configurable” que servirão de transferência de métricas
to_transfer AS (
    SELECT
        order_item_id as id,
        row_total,
        cost,
        freight_revenue,
        freight_cost,
        qty_ordered,
        part_qty_sold
    FROM skubase
    WHERE product_type = 'configurable'
),

-- Ajusta o item-filho usando os valores do item configurável (pai), se existir
last AS (
    SELECT
        z.created_at,
        z.timedate,
        z.order_item_id,
        z.increment_id,
        z.tiniciodahora_copiar,
        z.product_id,
        z.order_id,
        z.timedate                       AS trickat,
        z.product_options,
        z.product_type,
        z.parent_item_id,
        z.testsku,
        z.conversion,
        z.tiniciodahora,
        z.customer_email                 AS customer_email,
        z.postcode,
        z.country,
        z.region,
        z.city,
        z.street,
        z.phone_number                   AS telephone,
        z.customer_name,
        z.store_id,
        z.order_status                   AS status,
        z.vendor,
        z.customer_id,

        CASE WHEN ty.ID IS NOT NULL THEN Ty.Row_total ELSE z.row_total END AS row_total,
        CASE WHEN ty.ID IS NOT NULL THEN Ty.COST ELSE z.COST END AS cost,
        CASE WHEN ty.ID IS NOT NULL THEN Ty.qty_ordered ELSE z.qty_Ordered END AS qty_Ordered,
        CASE WHEN ty.ID IS NOT NULL THEN Ty.Part_Qty_Sold ELSE z.Part_Qty_Sold END AS part_qty_sold,
        CASE WHEN ty.ID IS NOT NULL THEN Ty.Freight_revenue ELSE z.freight_revenue END AS freight_revenue,
        CASE WHEN ty.ID IS NOT NULL THEN Ty.Freight_cost ELSE z.freight_cost END AS freight_cost,
        ty.cost            AS testc,
        ty.row_total       AS testr,
        ty.freight_revenue AS testfr,
        ty.freight_cost    AS testfc
     FROM skubase z
    LEFT JOIN to_transfer ty
           ON ty.id = z.parent_item_id
),


last_day_cost_last AS (
    SELECT
        l.product_id,
        MAX(l.trickat) AS last_scheduled_date
    FROM last l
    WHERE l.cost > 0
      AND l.qty_ordered > 0
    GROUP BY l.product_id
),

filtered_cost_prep AS (
    SELECT
        l.product_id,
        l.cost,
        l.qty_ordered AS qty,
        l.trickat
    FROM last l
    JOIN last_day_cost_last ld
      ON     l.product_id = ld.product_id
         AND l.trickat    = ld.last_scheduled_date
    WHERE l.cost > 0
      AND l.qty_ordered > 0
),

filtered_cost_final AS (
    SELECT
        product_id,
        SUM(cost) / NULLIF(SUM(qty), 0) AS cost,
        SUM(qty)                        AS qty,
        trickat                         AS trickat      -- só informativo
    FROM filtered_cost_prep
    GROUP BY product_id, trickat
)


SELECT
    l.created_at                            AS CREATED_AT,
    l.timedate                              AS TIMEDATE,
    l.order_item_id                         AS ID,
    l.increment_id                          AS INCREMENT_ID,
    l.tiniciodahora_copiar                  AS "Início da Hora - Copiar",
    l.product_id                            AS PRODUCT_ID,
    l.order_id                              AS ORDER_ID,
    l.trickat                               AS TRICKAT,
    l.product_options                       AS PRODUCT_OPTIONS,
    l.product_type                          AS PRODUCT_TYPE,
    l.parent_item_id                        AS PARENT_ITEM_ID,
    l.testsku                               AS TESTSKU,
    l.conversion                            AS CONVERSION,
    l.tiniciodahora                         AS "Início da Hora",
    l.customer_email                        AS CUSTOMER_EMAIL,
    l.postcode                              AS POSTCODE,
    l.country                               AS COUNTRY,
    l.region                                AS REGION,
    l.city                                  AS CITY,
    l.street                                AS STREET,
    l.telephone                             AS TELEPHONE,
    l.customer_name                         AS CUSTOMER_NAME,
    l.store_id                              AS STORE_ID,
    l.status                                AS STATUS,
    l.row_total                             AS ROW_TOTAL,
    COALESCE(l.cost, fcf.cost * l.qty_ordered) AS COST,
    l.qty_ordered                           AS QTY_ORDERED,
    l.freight_revenue                       AS FREIGHT_REVENUE,
    l.freight_cost                          AS FREIGHT_COST,
    l.testc                                 AS TESTC,
    l.testr                                 AS TESTR,
    l.testfr                                AS TESTFR,
    l.testfc                                AS TESTFC,
    l.vendor                                AS VENDOR,
    l.customer_id                           AS CUSTOMER_ID,
    cu.rank_id                              AS RANK_ID,
    COALESCE(l.part_qty_sold, l.qty_ordered) AS PART_QTY_SOLD
FROM last l
LEFT JOIN filtered_cost_final fcf
  ON fcf.product_id = l.product_id
LEFT JOIN {{ ref("magento_d_customerupdated") }} cu
  ON LOWER(
        COALESCE(
          NULLIF(l.customer_email, ''),
          'customer@nonidentified.com'
        )
     ) = cu.customer_email
WHERE l.product_type <> 'configurable'



