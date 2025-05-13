{{
  config(
    materialized = 'table',
    schema       = 'gold'
  )
}}

WITH constants AS (
    -- Define date ranges used throughout the query
    SELECT
        -- Current period
        TIMESTAMP '2021-01-01 04:00:00' AS start_date, -- Static start date? Consider making dynamic if needed
        CONVERT_TIMEZONE('America/New_York', 'UTC', GETDATE()) AS end_date, -- Redshift Syntax
        -- Previous period (seems identical to current in the original query, adjust if needed)
        TIMESTAMP '2021-01-01 04:00:00' AS previous_start_date,
        CONVERT_TIMEZONE('America/New_York', 'UTC', GETDATE()) AS previous_end_date -- Redshift Syntax
),

date_diffs AS (
    -- Pre-calculate date differences in days and weeks
    SELECT
        DATEDIFF('day', (SELECT previous_start_date FROM constants), (SELECT previous_end_date FROM constants)) AS previous_period_days,
        DATEDIFF('day', (SELECT previous_start_date FROM constants), (SELECT previous_end_date FROM constants)) / 7.0 AS previous_period_weeks
    FROM constants
    -- Ensure we only calculate this once
    LIMIT 1
),

part_sales_previous_period AS (
    -- Pre-calculate total quantity sold per part in the 'previous' period
    SELECT
        sub_p.part_number, -- Use renamed silver column from fishbowl_part
        SUM(sub_s.quantity_ordered * COALESCE(sub_uom.multiply_factor, 1)) AS total_part_qty_sold_previous_period -- Use renamed silver columns
    FROM
        {{ ref('magento_sales_order_item') }} sub_s
    JOIN
        {{ ref('magento_sales_order') }} sub_o
        ON sub_s.order_id = sub_o.order_id
    JOIN
        {{ ref('magento_catalog_product_entity') }} sub_cpe -- Assumes this silver model exists
        ON sub_s.sku = sub_cpe.sku -- Assumes sku exists
    JOIN
        {{ ref('fishbowl_product') }} sub_pr
        ON sub_cpe.sku = sub_pr.product_number -- Use renamed silver column
    JOIN
        {{ ref('fishbowl_part') }} sub_p
        ON sub_pr.part_id = sub_p.part_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} sub_uom
        ON sub_pr.uom_id = sub_uom.from_uom_id AND sub_uom.to_uom_id = 1 -- Use renamed silver columns
    WHERE
        sub_o.created_at >= (SELECT previous_start_date FROM constants)
        AND sub_o.created_at < (SELECT previous_end_date FROM constants)
        AND sub_s.product_type <> 'bundle'
        AND sub_s.unit_price > 0 -- Use renamed silver column
    GROUP BY
        sub_p.part_number
),

part_weekly_sales_previous_period AS (
    -- Calculate the average weekly sales rate based on the previous period
     SELECT
        pspp.part_number,
        pspp.total_part_qty_sold_previous_period,
        -- Calculate weekly rate, handle potential division by zero if period is less than a week (Redshift compatible)
        CASE
            WHEN dd.previous_period_weeks = 0 THEN 0
            ELSE pspp.total_part_qty_sold_previous_period / dd.previous_period_weeks
        END AS part_qty_sold_per_week_previous_period
     FROM part_sales_previous_period pspp
     CROSS JOIN date_diffs dd
),

inventory_totals AS (
    -- Pre-aggregate inventory totals by part_id
    SELECT
        part_id,
        SUM(quantity_on_hand - quantity_allocated - quantity_not_available) AS part_qty_available,
        SUM(quantity_on_order) AS qty_on_order
    FROM
        {{ ref('inventory_qtyinventorytotals') }} -- Corrected ref name
    GROUP BY
        part_id
),

vendor_info AS (
    -- Isolate vendor retrieval logic
    SELECT
        cpei.entity_id AS product_entity_id,
        MAX(eaov.value) AS vendor_name
    FROM
        {{ ref('magento_catalog_product_entity_int') }} cpei
    LEFT JOIN
        {{ ref('magento_eav_attribute_option_value') }} eaov
        ON cpei.value = eaov.option_id AND eaov.store_id = 0
    WHERE
        cpei.attribute_id = 145 -- Vendor attribute ID
    GROUP BY
        cpei.entity_id

),

main_aggregation AS (
    -- Performs the main joins and aggregations for the current period
    SELECT
        p.part_number,
        MAX(v.vendor_name) AS vendor_name,
        MAX(s.product_name) AS product_name,
        SUM(s.quantity_ordered * COALESCE(uom.multiply_factor, 1)) AS part_qty_sold_current_period,
        SUM(s.row_total) AS total_revenue_current_period,
        MAX(it.part_qty_available) AS part_qty_available,
        MAX(it.qty_on_order) AS qty_on_order,
        MAX(pc.average_cost) AS part_cost
    FROM
        {{ ref('magento_sales_order_item') }} s
    JOIN
        {{ ref('magento_sales_order') }} o
        ON s.order_id = o.order_id
    JOIN
        {{ ref('magento_catalog_product_entity') }} cpe
        ON s.sku = cpe.sku
    LEFT JOIN vendor_info v
        ON cpe.product_entity_id = v.product_entity_id
    JOIN
        {{ ref('fishbowl_product') }} pr
        ON cpe.sku = pr.product_number
    JOIN
        {{ ref('fishbowl_part') }} p
        ON pr.part_id = p.part_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uom
        ON pr.uom_id = uom.from_uom_id AND uom.to_uom_id = 1
    LEFT JOIN inventory_totals it
        ON p.part_id = it.part_id
    LEFT JOIN
        {{ ref('fishbowl_partcost') }} pc
        ON p.part_id = pc.part_id
    WHERE
        o.created_at >= (SELECT start_date FROM constants)
        AND o.created_at <= (SELECT end_date FROM constants)
        AND s.product_type <> 'bundle'
        AND s.unit_price > 0
    GROUP BY
        p.part_number
)

-- Final selection and calculation of derived metrics
SELECT
    ma.part_number,
    ma.vendor_name AS vendor,
    ma.product_name AS name,
    ma.part_qty_sold_current_period,
    ma.total_revenue_current_period,
    COALESCE(pws.part_qty_sold_per_week_previous_period, 0) AS part_qty_sold_per_week_previous_period,
    ma.part_qty_available,
    -- Calculate Weeks on Hand using the pre-calculated weekly sales rate (Redshift compatible)
    CASE
        WHEN pws.part_qty_sold_per_week_previous_period = 0 THEN NULL -- Or potentially a very large number / indicator
        ELSE ma.part_qty_available / pws.part_qty_sold_per_week_previous_period
    END AS weeks_on_hand,
    ma.part_cost,
    ma.part_qty_available * ma.part_cost AS extended_cost,
    ma.qty_on_order
FROM
    main_aggregation ma
LEFT JOIN part_weekly_sales_previous_period pws
    ON ma.part_number = pws.part_number
