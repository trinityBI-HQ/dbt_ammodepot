-- =============================================================================
-- Cortex Analyst Chatbot — Bootstrap Setup
-- Run as ACCOUNTADMIN (one-time setup)
--
-- Creates:
--   1. Semantic View in AD_ANALYTICS.GOLD
--   2. RBAC grants for viewer roles
--   3. Stage for the Streamlit app (if not exists)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Grant semantic view creation to TRANSFORMER_ROLE
GRANT CREATE SEMANTIC VIEW ON SCHEMA AD_ANALYTICS.GOLD TO ROLE TRANSFORMER_ROLE;

-- =============================================================================
-- 1. Create the Semantic View
-- =============================================================================

USE ROLE TRANSFORMER_ROLE;
USE SCHEMA AD_ANALYTICS.GOLD;

-- SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML creates the view from YAML.
-- The view name comes from the YAML 'name:' field.
-- First arg = target schema, second arg = YAML body.
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'AD_ANALYTICS.GOLD',
  $$
name: AMMODEPOT_ANALYST
description: >
  Sales, inventory, procurement, product, vendor, and customer segmentation
  data for Ammunition Depot. Covers 6 Gold layer tables for natural language
  querying by operations and executive teams.

tables:
  # ── F_SALES ────────────────────────────────────────────────────────────────
  - name: sales
    description: "Order line items from Magento (website) and Fishbowl (GunBroker). One row per item sold."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: F_SALES
    dimensions:
      - name: status
        expr: STATUS
        data_type: VARCHAR
        description: "Order status: COMPLETE, PROCESSING, UNVERIFIED, CANCELED, CLOSED"
        is_enum: true
        synonyms: ["order status"]
      - name: storefront
        expr: STOREFRONT
        data_type: VARCHAR
        description: "Sales channel: Website (Magento) or GunBroker"
        is_enum: true
        synonyms: ["channel", "store"]
      - name: customer_email
        expr: CUSTOMER_EMAIL
        data_type: VARCHAR
        description: "Customer email address"
        synonyms: ["email", "customer"]
      - name: customer_name
        expr: CUSTOMER_NAME
        data_type: VARCHAR
        description: "Customer full name"
      - name: region
        expr: REGION
        data_type: VARCHAR
        description: "Billing state/province"
        synonyms: ["state"]
      - name: city
        expr: CITY
        data_type: VARCHAR
      - name: postcode
        expr: POSTCODE
        data_type: VARCHAR
        description: "Billing ZIP code"
        synonyms: ["zip", "zip code"]
      - name: product_id
        expr: PRODUCT_ID
        data_type: NUMBER
        description: "Magento product entity ID (FK to products)"
      - name: order_id
        expr: ORDER_ID
        data_type: NUMBER
        description: "Magento order entity ID"
      - name: increment_id
        expr: INCREMENT_ID
        data_type: VARCHAR
        description: "Human-readable order number"
        synonyms: ["order number"]
      - name: vendor
        expr: VENDOR
        data_type: NUMBER
        description: "Fishbowl vendor ID (FK to vendors)"
        synonyms: ["vendor_id"]
      - name: rank_id
        expr: RANK_ID
        data_type: NUMBER
        description: "Customer rank ID for segmentation join (FK to customer_segments)"
    time_dimensions:
      - name: created_at
        expr: CREATED_AT
        data_type: TIMESTAMP_NTZ
        description: "Order creation date/time in Eastern (EDT/EST)"
        synonyms: ["date", "sale date", "order date"]
    facts:
      - name: row_total
        expr: ROW_TOTAL
        data_type: NUMBER
        description: "Net line item revenue in USD (after discount)"
        synonyms: ["revenue", "sales", "net sales"]
      - name: cost
        expr: COST
        data_type: NUMBER
        description: "Cost of goods sold per line item"
        synonyms: ["cogs"]
      - name: qty_ordered
        expr: QTY_ORDERED
        data_type: NUMBER
        description: "Units ordered"
        synonyms: ["units", "quantity"]
      - name: freight_revenue
        expr: FREIGHT_REVENUE
        data_type: NUMBER
        description: "Shipping revenue allocated to this line item"
      - name: freight_cost
        expr: FREIGHT_COST
        data_type: NUMBER
        description: "Shipping cost allocated to this line item"
      - name: part_qty_sold
        expr: PART_QTY_SOLD
        data_type: NUMBER
        description: "Piece quantity sold (adjusted by UOM conversion)"
    metrics:
      - name: total_revenue
        expr: SUM(row_total)
        description: "Total net revenue"
        synonyms: ["gross sales", "total sales"]
      - name: total_orders
        expr: COUNT(DISTINCT order_id)
        description: "Count of unique orders"
      - name: gross_profit
        expr: SUM(row_total) - SUM(cost)
        description: "Gross profit (revenue minus COGS)"
        synonyms: ["GP", "profit"]
      - name: gross_margin
        expr: (SUM(row_total) - SUM(cost)) / NULLIF(SUM(row_total), 0)
        description: "Gross margin percentage"
        synonyms: ["margin"]
      - name: aov
        expr: SUM(row_total) / NULLIF(COUNT(DISTINCT order_id), 0)
        description: "Average order value"
        synonyms: ["average order value", "avg ticket"]
      - name: total_units
        expr: SUM(qty_ordered)
        description: "Total units sold"
    filters:
      - name: standard_statuses
        description: "Active orders (excludes CANCELED, CLOSED)"
        expr: "status IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')"

  # ── F_INVENTORYVIEW ────────────────────────────────────────────────────────
  - name: inventory
    description: "Current inventory snapshot. One row per part number."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: F_INVENTORYVIEW
    dimensions:
      - name: part_number
        expr: PART_NUMBER
        data_type: VARCHAR
        unique: true
        description: "SKU / part number"
        synonyms: ["sku"]
    facts:
      - name: qty_available
        expr: QTY_AVAILABLE
        data_type: NUMBER
        description: "Units currently in stock"
        synonyms: ["on hand", "in stock"]
      - name: qty_not_available
        expr: QTY_NOT_AVAILABLE
        data_type: NUMBER
        description: "Units reserved or held"
      - name: qty_on_order
        expr: QTY_ON_ORDER
        data_type: NUMBER
        description: "Units on outstanding purchase orders"
        synonyms: ["on order"]
      - name: part_cost
        expr: PART_COST
        data_type: NUMBER
        description: "Unit cost (max of average costs)"
      - name: extended_cost
        expr: EXTENDED_COST
        data_type: NUMBER
        description: "Total inventory valuation (qty * cost)"
    metrics:
      - name: total_on_hand
        expr: SUM(qty_available)
        description: "Total units in stock across all SKUs"
      - name: total_inventory_value
        expr: SUM(extended_cost)
        description: "Total dollar value of current inventory"
        synonyms: ["inventory cost", "stock value"]
      - name: total_on_order
        expr: SUM(qty_on_order)
        description: "Total units on open purchase orders"

  # ── F_POS ──────────────────────────────────────────────────────────────────
  - name: purchase_orders
    description: "Purchase order receipt lines. One row per received item."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: F_POS
    dimensions:
      - name: part_number
        expr: PART_NUMBER
        data_type: VARCHAR
        description: "SKU / part number received"
      - name: vendor_id
        expr: VENDOR_ID
        data_type: NUMBER
        description: "Fishbowl vendor ID (FK to vendors)"
      - name: purchase_order_id
        expr: PURCHASE_ORDER_ID
        data_type: NUMBER
        description: "PO identifier"
        synonyms: ["PO", "PO number"]
      - name: receipt_item_status_id
        expr: RECEIPT_ITEM_STATUS_ID
        data_type: NUMBER
        description: "2=Received, 4=Reconciled"
        is_enum: true
        synonyms: ["receipt status"]
    time_dimensions:
      - name: po_created_at
        expr: PO_CREATED_AT
        data_type: TIMESTAMP_NTZ
        description: "Date PO was created"
        synonyms: ["PO date", "order date"]
      - name: datereceived
        expr: DATERECEIVED
        data_type: TIMESTAMP_NTZ
        description: "Date item was received (NULL if not yet received)"
        synonyms: ["date received", "receipt date"]
    facts:
      - name: qty
        expr: QTY
        data_type: NUMBER
        description: "Quantity received on this line"
        synonyms: ["quantity received"]
      - name: unit_cost
        expr: UNIT_COST
        data_type: NUMBER
        description: "Per-unit purchase cost"
      - name: total_cost
        expr: TOTAL_COST
        data_type: NUMBER
        description: "Total cost for this receipt line"
      - name: precise_leadtime
        expr: PRECISE_LEADTIME
        data_type: NUMBER
        description: "Best available lead time in days (vendor-product > vendor > product)"
        synonyms: ["lead time", "delivery time"]
      - name: quantity_to_fulfill
        expr: QUANTITY_TO_FULFILL
        data_type: NUMBER
        description: "Quantity still to be delivered on this PO item"
        synonyms: ["qty to fulfill"]
      - name: quantity_fulfilled
        expr: QUANTITY_FULFILLED
        data_type: NUMBER
        description: "Quantity already delivered on this PO item"
        synonyms: ["qty fulfilled"]
    metrics:
      - name: avg_lead_time
        expr: AVG(precise_leadtime)
        description: "Average lead time in days"
      - name: total_po_cost
        expr: SUM(total_cost)
        description: "Total procurement cost"
      - name: total_qty_received
        expr: SUM(qty)
        description: "Total units received"
    filters:
      - name: open_pos
        description: "PO items not yet received"
        expr: "datereceived IS NULL AND quantity_to_fulfill > 0"

  # ── D_PRODUCT (via D_PRODUCT_ANALYST view — UPPERCASE unquoted columns) ──
  - name: products
    description: "Product catalog with ammunition attributes. One row per product. Uses D_PRODUCT_ANALYST view to avoid mixed-case quoted column issues."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: INT_PRODUCT_ANALYST
    primary_key:
      columns:
        - product_id
    dimensions:
      - name: product_id
        expr: PRODUCT_ID
        data_type: NUMBER
        unique: true
        description: "Magento product entity ID (primary key)"
      - name: sku
        expr: SKU
        data_type: VARCHAR
        unique: true
        description: "Stock keeping unit"
      - name: product_name
        expr: PRODUCT_NAME
        data_type: VARCHAR
        description: "Full product name"
        synonyms: ["product", "item", "name"]
      - name: caliber
        expr: CALIBER
        data_type: VARCHAR
        description: "Ammunition caliber (e.g., 9mm, 5.56 NATO, .308 Win)"
      - name: manufacturer
        expr: MANUFACTURER
        data_type: VARCHAR
        description: "Manufacturer / brand name"
        synonyms: ["brand", "maker", "mfr"]
      - name: projectile
        expr: PROJECTILE
        data_type: VARCHAR
        description: "Projectile type: FMJ, JHP, SP, HP, Buck, Slug, etc."
      - name: product_vendor
        expr: PRODUCT_VENDOR
        data_type: VARCHAR
        description: "Fishbowl vendor / fulfillment source"
        synonyms: ["fulfilled by", "supplier", "vendor"]
      - name: use_type_category
        expr: USE_TYPE_CATEGORY
        data_type: VARCHAR
        description: "Product use classification: Hunting, Self-Defense, Tactical, Sporting, Collector, Unclassified"
        is_enum: true
        synonyms: ["use type", "product type", "use case"]
      - name: primary_category
        expr: PRIMARY_CATEGORY
        data_type: VARCHAR
        description: "Top-level product category: Ammunition, Guns, Magazines, Gun Parts, Gear, Optics, etc."
        is_enum: true
        synonyms: ["category"]
      - name: discontinued
        expr: DISCONTINUED
        data_type: BOOLEAN
        description: "Whether the product is discontinued"
      - name: unit_type
        expr: UNIT_TYPE
        data_type: VARCHAR
        description: "Unit of measure (Box, Case, Each)"
    facts:
      - name: avgcost
        expr: AVGCOST
        data_type: NUMBER
        description: "Average cost from Fishbowl"
        synonyms: ["average cost"]
      - name: lastvendorcost
        expr: LASTVENDORCOST
        data_type: NUMBER
        description: "Most recent vendor cost"
        synonyms: ["last vendor cost"]

  # ── D_VENDOR ───────────────────────────────────────────────────────────────
  - name: vendors
    description: "Vendor/supplier master data. One row per vendor."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: D_VENDOR
    primary_key:
      columns:
        - vendor_id
    dimensions:
      - name: vendor_id
        expr: VENDOR_ID
        data_type: NUMBER
        unique: true
        description: "Fishbowl vendor ID (primary key)"
      - name: vendor_name
        expr: VENDOR_NAME
        data_type: VARCHAR
        description: "Supplier / vendor name"
        synonyms: ["vendor", "supplier"]
      - name: is_active
        expr: IS_ACTIVE
        data_type: BOOLEAN
        description: "Whether the vendor is currently active"
    facts:
      - name: default_lead_time
        expr: LEAD_TIME_DAYS
        data_type: NUMBER
        description: "Default lead time in days"
      - name: credit_limit
        expr: CREDIT_LIMIT
        data_type: NUMBER
        description: "Vendor credit limit"
      - name: min_order_amount
        expr: MINIMUM_ORDER_AMOUNT
        data_type: NUMBER
        description: "Minimum order amount"
    filters:
      - name: active_vendors
        description: "Only active vendors"
        expr: "IS_ACTIVE = TRUE"

  # ── D_CUSTOMER_SEGMENTATION ────────────────────────────────────────────────
  - name: customer_segments
    description: "RFM customer segmentation with 16 classifications. One row per unique customer."
    base_table:
      database: AD_ANALYTICS
      schema: GOLD
      table: D_CUSTOMER_SEGMENTATION
    primary_key:
      columns:
        - rank_id
    dimensions:
      - name: customer_email
        expr: CUSTOMER_EMAIL
        data_type: VARCHAR
        description: "Customer email"
      - name: rank_id
        expr: RANK_ID
        data_type: NUMBER
        unique: true
        description: "Deduplicated customer ID (primary key)"
      - name: frequency
        expr: FREQUENCY
        data_type: VARCHAR
        description: "Purchase frequency band: F0 (none) to F5 (6+ purchases in 12 months)"
        is_enum: true
      - name: recency
        expr: RECENCY
        data_type: VARCHAR
        description: "Recency band: R0 (>365 days) to R5 (within 30 days)"
        is_enum: true
      - name: value
        expr: VALUE
        data_type: VARCHAR
        description: "Revenue band: V0 (none) to V5 (>$500 in 12 months)"
        is_enum: true
        synonyms: ["value band"]
      - name: margin_classification
        expr: MARGIN_CLASSIFICATION
        data_type: VARCHAR
        description: "Margin band: M0 (none) to M5 (>=30%)"
        is_enum: true
        synonyms: ["margin band"]
      - name: monetary_value
        expr: MONETARY_VALUE
        data_type: VARCHAR
        description: "Combined value+margin score: MV0 to MV5"
        is_enum: true
      - name: customer_classification
        expr: CUSTOMER_CLASSIFICATION
        data_type: VARCHAR
        description: "Customer segment: Super Engaged, At-Risk Regular, Lost Buyer, New Buyer, etc. (16 segments)"
        is_enum: true
        synonyms: ["segment", "customer type", "classification"]
      - name: customer_group
        expr: CUSTOMER_GROUP
        data_type: VARCHAR
        description: "Account type: General, Law Enforcement, Wholesale, Retailer, NOT LOGGED IN"
        is_enum: true
        synonyms: ["group", "account type"]
    facts:
      - name: total_revenue
        expr: TOTAL_REVENUE
        data_type: NUMBER
        description: "Customer revenue in trailing 12 months"
      - name: number_of_purchases
        expr: NUMBER_OF_PURCHASES
        data_type: NUMBER
        description: "Number of purchases in trailing 12 months"
        synonyms: ["purchase count"]
      - name: days_since_last_purchase
        expr: DAYS_SINCE_LAST_PURCHASE
        data_type: NUMBER
        description: "Days since most recent purchase"
      - name: total_purchases_all_time
        expr: TOTAL_PURCHASES_ALL_TIME
        data_type: NUMBER
        description: "Total purchases across all time (any status)"
        synonyms: ["lifetime purchases"]
    metrics:
      - name: customer_count
        expr: COUNT(DISTINCT rank_id)
        description: "Number of unique customers"
      - name: avg_customer_revenue
        expr: AVG(total_revenue)
        description: "Average 12-month revenue per customer"

# ── RELATIONSHIPS ──────────────────────────────────────────────────────────
relationships:
  - name: sales_to_products
    left_table: sales
    right_table: products
    relationship_columns:
      - left_column: product_id
        right_column: product_id
  - name: sales_to_vendors
    left_table: sales
    right_table: vendors
    relationship_columns:
      - left_column: vendor
        right_column: vendor_id
  - name: sales_to_segments
    left_table: sales
    right_table: customer_segments
    relationship_columns:
      - left_column: rank_id
        right_column: rank_id
  - name: pos_to_vendors
    left_table: purchase_orders
    right_table: vendors
    relationship_columns:
      - left_column: vendor_id
        right_column: vendor_id

# ── VERIFIED QUERIES (Golden Questions) ────────────────────────────────────
verified_queries:
  - name: total_revenue_today
    question: "What is total revenue today?"
    sql: |
      SELECT SUM(ROW_TOTAL) AS TOTAL_REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE = CURRENT_DATE()
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: gross_margin_this_month
    question: "What is our gross margin this month?"
    sql: |
      SELECT
        ROUND(
          (SUM(ROW_TOTAL) - SUM(COST)) / NULLIF(SUM(ROW_TOTAL), 0) * 100,
          2
        ) AS GROSS_MARGIN_PCT
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE DATE_TRUNC('MONTH', CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: top_10_products_this_week
    question: "Top 10 products by revenue this week"
    sql: |
      SELECT
        p."Product Name" AS PRODUCT_NAME,
        p.SKU,
        SUM(s.ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES s
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON s.PRODUCT_ID = p."Product ID"
      WHERE s.CREATED_AT >= DATE_TRUNC('WEEK', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY p."Product Name", p.SKU
      ORDER BY REVENUE DESC
      LIMIT 10
    verified_by: "Victor"

  - name: total_orders_yesterday_vs_day_before
    question: "Total orders yesterday vs day before"
    sql: |
      SELECT
        CREATED_AT::DATE AS ORDER_DATE,
        COUNT(DISTINCT ORDER_ID) AS TOTAL_ORDERS
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE IN (CURRENT_DATE() - 1, CURRENT_DATE() - 2)
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY ORDER_DATE
      ORDER BY ORDER_DATE DESC
    verified_by: "Victor"

  - name: revenue_by_category_mtd
    question: "Revenue by category this month"
    sql: |
      SELECT
        p."Primary Category" AS CATEGORY,
        SUM(s.ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES s
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON s.PRODUCT_ID = p."Product ID"
      WHERE DATE_TRUNC('MONTH', s.CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY p."Primary Category"
      ORDER BY REVENUE DESC
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: top_5_manufacturers_units_mtd
    question: "Top 5 manufacturers by units sold this month"
    sql: |
      SELECT
        p."Manufacturer SKU" AS MANUFACTURER,
        SUM(s.QTY_ORDERED) AS UNITS_SOLD
      FROM AD_ANALYTICS.GOLD.F_SALES s
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON s.PRODUCT_ID = p."Product ID"
      WHERE DATE_TRUNC('MONTH', s.CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY p."Manufacturer SKU"
      ORDER BY UNITS_SOLD DESC
      LIMIT 5
    verified_by: "Victor"

  - name: units_9mm_in_stock
    question: "How many units of 9mm are in stock?"
    sql: |
      SELECT SUM(i.QTY_AVAILABLE) AS UNITS_IN_STOCK
      FROM AD_ANALYTICS.GOLD.F_INVENTORYVIEW i
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON i.PART_NUMBER = p.SKU
      WHERE p."Caliber" ILIKE '%9mm%'
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: vendors_longest_lead_times
    question: "Which vendors have the longest lead times?"
    sql: |
      SELECT
        v.VENDOR_NAME,
        ROUND(AVG(po.PRECISE_LEADTIME), 1) AS AVG_LEAD_TIME_DAYS,
        COUNT(*) AS RECEIPT_COUNT
      FROM AD_ANALYTICS.GOLD.F_POS po
      JOIN AD_ANALYTICS.GOLD.D_VENDOR v ON po.VENDOR_ID = v.VENDOR_ID
      WHERE po.PRECISE_LEADTIME IS NOT NULL
      GROUP BY v.VENDOR_NAME
      HAVING COUNT(*) >= 5
      ORDER BY AVG_LEAD_TIME_DAYS DESC
      LIMIT 10
    verified_by: "Victor"

  - name: open_pos_not_received
    question: "Show me open POs not yet received"
    sql: |
      SELECT
        po.PURCHASE_ORDER_ID AS PO_ID,
        v.VENDOR_NAME,
        p.SKU,
        p."Product Name" AS PRODUCT_NAME,
        po.QUANTITY_TO_FULFILL AS QTY_PENDING,
        po.UNIT_COST,
        po.PO_CREATED_AT::DATE AS PO_DATE
      FROM AD_ANALYTICS.GOLD.F_POS po
      JOIN AD_ANALYTICS.GOLD.D_VENDOR v ON po.VENDOR_ID = v.VENDOR_ID
      JOIN AD_ANALYTICS.GOLD.D_PRODUCT p ON po.PART_NUMBER = p.SKU
      WHERE po.DATERECEIVED IS NULL
        AND po.QUANTITY_TO_FULFILL > 0
      ORDER BY po.PO_CREATED_AT DESC
      LIMIT 50
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: at_risk_regular_count
    question: "How many customers are classified as At-Risk Regular?"
    sql: |
      SELECT COUNT(DISTINCT RANK_ID) AS AT_RISK_REGULAR_COUNT
      FROM AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION
      WHERE CUSTOMER_CLASSIFICATION = 'At-Risk Regular'
    verified_by: "Victor"

  # ── PBI Top 20 — Additional Verified Queries ──────────────────────────────

  - name: revenue_mtd_vs_prior_month
    question: "Revenue MTD vs prior month"
    sql: |
      SELECT
        'Current MTD' AS PERIOD,
        SUM(ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE DATE_TRUNC('MONTH', CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND CREATED_AT::DATE <= CURRENT_DATE()
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      UNION ALL
      SELECT
        'Prior Month MTD' AS PERIOD,
        SUM(ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE BETWEEN DATE_TRUNC('MONTH', DATEADD('MONTH', -1, CURRENT_DATE()))
        AND DATEADD('MONTH', -1, CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: revenue_ytd_vs_prior_year
    question: "Revenue YTD vs prior year"
    sql: |
      SELECT
        'Current YTD' AS PERIOD,
        SUM(ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE DATE_TRUNC('YEAR', CREATED_AT) = DATE_TRUNC('YEAR', CURRENT_DATE())
        AND CREATED_AT::DATE <= CURRENT_DATE()
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      UNION ALL
      SELECT
        'Prior Year YTD' AS PERIOD,
        SUM(ROW_TOTAL) AS REVENUE
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE BETWEEN DATE_TRUNC('YEAR', DATEADD('YEAR', -1, CURRENT_DATE()))
        AND DATEADD('YEAR', -1, CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
    verified_by: "Victor"

  - name: daily_revenue_last_30_days
    question: "Daily revenue trend last 30 days"
    sql: |
      SELECT
        CREATED_AT::DATE AS SALE_DATE,
        SUM(ROW_TOTAL) AS REVENUE,
        COUNT(DISTINCT ORDER_ID) AS ORDERS
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE CREATED_AT::DATE >= DATEADD('DAY', -30, CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY SALE_DATE
      ORDER BY SALE_DATE
    verified_by: "Victor"

  - name: revenue_by_caliber_mtd
    question: "Revenue by caliber this month"
    sql: |
      SELECT
        p.CALIBER,
        SUM(s.ROW_TOTAL) AS REVENUE,
        SUM(s.QTY_ORDERED) AS UNITS_SOLD
      FROM AD_ANALYTICS.GOLD.F_SALES s
      JOIN AD_ANALYTICS.GOLD.INT_PRODUCT_ANALYST p ON s.PRODUCT_ID = p.PRODUCT_ID
      WHERE DATE_TRUNC('MONTH', s.CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY p.CALIBER
      ORDER BY REVENUE DESC
    verified_by: "Victor"

  - name: margin_by_manufacturer
    question: "Product margin by manufacturer"
    sql: |
      SELECT
        p.MANUFACTURER,
        SUM(s.ROW_TOTAL) AS REVENUE,
        SUM(s.COST) AS TOTAL_COST,
        ROUND((SUM(s.ROW_TOTAL) - SUM(s.COST)) / NULLIF(SUM(s.ROW_TOTAL), 0) * 100, 2) AS MARGIN_PCT
      FROM AD_ANALYTICS.GOLD.F_SALES s
      JOIN AD_ANALYTICS.GOLD.INT_PRODUCT_ANALYST p ON s.PRODUCT_ID = p.PRODUCT_ID
      WHERE DATE_TRUNC('MONTH', s.CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY p.MANUFACTURER
      HAVING SUM(s.ROW_TOTAL) > 0
      ORDER BY REVENUE DESC
      LIMIT 20
    verified_by: "Victor"

  - name: revenue_by_storefront
    question: "Revenue by storefront this month"
    sql: |
      SELECT
        STOREFRONT,
        SUM(ROW_TOTAL) AS REVENUE,
        COUNT(DISTINCT ORDER_ID) AS ORDERS,
        ROUND(SUM(ROW_TOTAL) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS AOV
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE DATE_TRUNC('MONTH', CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY STOREFRONT
      ORDER BY REVENUE DESC
    verified_by: "Victor"

  - name: top_states_by_revenue
    question: "Top states by revenue this month"
    sql: |
      SELECT
        REGION AS STATE,
        SUM(ROW_TOTAL) AS REVENUE,
        COUNT(DISTINCT ORDER_ID) AS ORDERS
      FROM AD_ANALYTICS.GOLD.F_SALES
      WHERE DATE_TRUNC('MONTH', CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
        AND REGION IS NOT NULL
      GROUP BY REGION
      ORDER BY REVENUE DESC
      LIMIT 15
    verified_by: "Victor"

  - name: aov_by_store
    question: "Average order value by store"
    sql: |
      SELECT
        s.STORE_ID,
        d.NAME AS STORE_NAME,
        ROUND(SUM(s.ROW_TOTAL) / NULLIF(COUNT(DISTINCT s.ORDER_ID), 0), 2) AS AOV,
        COUNT(DISTINCT s.ORDER_ID) AS ORDERS
      FROM AD_ANALYTICS.GOLD.F_SALES s
      LEFT JOIN AD_ANALYTICS.GOLD.D_STORE d ON s.STORE_ID = d.STORE_ID
      WHERE DATE_TRUNC('MONTH', s.CREATED_AT) = DATE_TRUNC('MONTH', CURRENT_DATE())
        AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
      GROUP BY s.STORE_ID, d.NAME
      ORDER BY AOV DESC
    verified_by: "Victor"

  - name: total_inventory_value
    question: "Total inventory value on hand"
    sql: |
      SELECT
        SUM(QTY_AVAILABLE) AS TOTAL_UNITS,
        SUM(EXTENDED_COST) AS TOTAL_VALUE
      FROM AD_ANALYTICS.GOLD.F_INVENTORYVIEW
    verified_by: "Victor"
    use_as_onboarding_question: true

  - name: customer_segment_distribution
    question: "Customer count by segment"
    sql: |
      SELECT
        CUSTOMER_CLASSIFICATION AS SEGMENT,
        COUNT(DISTINCT RANK_ID) AS CUSTOMER_COUNT,
        ROUND(AVG(TOTAL_REVENUE), 2) AS AVG_REVENUE,
        ROUND(AVG(DAYS_SINCE_LAST_PURCHASE), 0) AS AVG_DAYS_SINCE_LAST
      FROM AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION
      GROUP BY CUSTOMER_CLASSIFICATION
      ORDER BY CUSTOMER_COUNT DESC
    verified_by: "Victor"
$$
);

-- =============================================================================
-- 2. RBAC Grants
-- =============================================================================

USE ROLE ACCOUNTADMIN;

GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST
  TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST
  TO ROLE POWERBI_READONLY_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST
  TO ROLE STREAMLIT_ROLE;

-- =============================================================================
-- 3. Stage for Streamlit app (if not already created by snow cli)
-- =============================================================================

USE ROLE STREAMLIT_ROLE;

CREATE STAGE IF NOT EXISTS AD_ANALYTICS.OPS.ANALYST_STAGE
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
