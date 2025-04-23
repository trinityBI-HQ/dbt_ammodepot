{{ config(
    materialized = 'view',
    schema       = 'gold'
) }}

WITH 

-- 0. Customer base: rank_id ↔ email
customer_base AS (
  SELECT
    rank_id,
    customer_email
  FROM {{ ref('magento_d_customerupdated') }}
),

-- 1. Total purchases all time
total_purchases AS (
    SELECT 
        cb.rank_id,
        COUNT(DISTINCT fs.order_id) AS total_purchases_all_time
    FROM {{ ref('f_sales') }}           AS fs
    JOIN customer_base                 AS cb 
      ON fs.customer_email = cb.customer_email
    WHERE fs.order_status IN ('PROCESSING','COMPLETE','UNVERIFIED')
    GROUP BY cb.rank_id
),

-- 2. Sales in the last 12 months (up to end of prior month)
customer_sales AS (
    SELECT 
        cb.rank_id,
        COUNT(DISTINCT fs.order_id)                   AS number_of_purchases,
        SUM(fs.row_total)                             AS total_revenue,
        CASE 
          WHEN SUM(fs.row_total) = 0 
          THEN NULL 
          ELSE (SUM(fs.row_total) - SUM(fs.cost))::DOUBLE PRECISION 
               / SUM(fs.row_total)
        END                                           AS margin,
        datediff(
          day,
          MAX(fs.created_at),
          dateadd(
            day, -1,
            date_trunc('month', convert_timezone('UTC','America/New_York',current_date))
          )
        )                                             AS days_since_last_purchase
    FROM {{ ref('f_sales') }}           AS fs
    JOIN customer_base                 AS cb 
      ON fs.customer_email = cb.customer_email
    WHERE
      fs.created_at >= dateadd(
        year, -1,
        date_trunc('month', convert_timezone('UTC','America/New_York',current_date))
      )
      AND fs.created_at < date_trunc('month', convert_timezone('UTC','America/New_York',current_date))
      AND fs.order_status IN ('PROCESSING','COMPLETE','UNVERIFIED')
    GROUP BY cb.rank_id
),

-- 3. Assemble base customer + metrics
d_customerupdatesview AS (
    SELECT 
        cb.rank_id,
        cb.customer_email,
        cs.number_of_purchases,
        cs.total_revenue,
        cs.margin,
        cs.days_since_last_purchase,
        tp.total_purchases_all_time,

        -- Frequency label & int
        CASE 
          WHEN cs.number_of_purchases = 1   THEN 'F1'
          WHEN cs.number_of_purchases <= 2  THEN 'F2'
          WHEN cs.number_of_purchases <= 3  THEN 'F3'
          WHEN cs.number_of_purchases <= 5  THEN 'F4'
          WHEN cs.number_of_purchases >= 5  THEN 'F5'
          ELSE 'F0'
        END                                AS frequency,
        CASE 
          WHEN cs.number_of_purchases = 1   THEN 1
          WHEN cs.number_of_purchases <= 2  THEN 2
          WHEN cs.number_of_purchases <= 3  THEN 3
          WHEN cs.number_of_purchases <= 5  THEN 4
          WHEN cs.number_of_purchases >= 5  THEN 5
          ELSE 0
        END                                AS frequency_int,

        -- Recency label & int
        CASE 
          WHEN cs.days_since_last_purchase <= 30 THEN 'R5'
          WHEN cs.days_since_last_purchase <= 60 THEN 'R4'
          WHEN cs.days_since_last_purchase <= 180 THEN 'R3'
          WHEN cs.days_since_last_purchase <= 240 THEN 'R2'
          WHEN cs.days_since_last_purchase <= 365 THEN 'R1'
          ELSE 'R0'
        END                                AS recency,
        CASE 
          WHEN cs.days_since_last_purchase <= 30 THEN 5
          WHEN cs.days_since_last_purchase <= 60 THEN 4
          WHEN cs.days_since_last_purchase <= 120 THEN 3
          WHEN cs.days_since_last_purchase <= 180 THEN 2
          WHEN cs.days_since_last_purchase <= 365 THEN 1
          ELSE 0
        END                                AS recency_int,

        -- Value label & int
        CASE 
          WHEN cs.total_revenue < 149   THEN 'V1'
          WHEN cs.total_revenue <= 225  THEN 'V2'
          WHEN cs.total_revenue <= 300  THEN 'V3'
          WHEN cs.total_revenue <= 500  THEN 'V4'
          WHEN cs.total_revenue > 500   THEN 'V5'
          ELSE 'V0'
        END                                AS value,
        CASE 
          WHEN cs.total_revenue < 149   THEN 1
          WHEN cs.total_revenue <= 225  THEN 2
          WHEN cs.total_revenue <= 300  THEN 3
          WHEN cs.total_revenue <= 500  THEN 4
          WHEN cs.total_revenue > 500   THEN 5
          ELSE 0
        END                                AS value_int,

        -- Margin classification & int
        CASE 
          WHEN cs.margin < 0.20         THEN 'M1'
          WHEN cs.margin < 0.24         THEN 'M2'
          WHEN cs.margin < 0.26         THEN 'M3'
          WHEN cs.margin < 0.30         THEN 'M4'
          WHEN cs.margin >= 0.30        THEN 'M5'
          ELSE 'M0'
        END                                AS margin_classification,
        CASE 
          WHEN cs.margin < 0.20         THEN 1
          WHEN cs.margin < 0.24         THEN 2
          WHEN cs.margin < 0.26         THEN 3
          WHEN cs.margin < 0.30         THEN 4
          WHEN cs.margin >= 0.30        THEN 5
          ELSE 0
        END                                AS margin_int
    FROM customer_base               AS cb
    LEFT JOIN customer_sales        AS cs ON cb.rank_id = cs.rank_id
    LEFT JOIN total_purchases       AS tp ON cb.rank_id = tp.rank_id
),

-- 4. RFM + Monetary Value segmentation
Segmentation AS (
    SELECT 
        dv.*,

        CASE
          WHEN floor((dv.margin_int + dv.value_int)/2) = 1 THEN 'MV1'
          WHEN floor((dv.margin_int + dv.value_int)/2) = 2 THEN 'MV2'
          WHEN floor((dv.margin_int + dv.value_int)/2) = 3 THEN 'MV3'
          WHEN floor((dv.margin_int + dv.value_int)/2) = 4 THEN 'MV4'
          WHEN floor((dv.margin_int + dv.value_int)/2) = 5 THEN 'MV5'
          ELSE 'MV0'
        END                                AS monetary_value,

        CASE
          WHEN dv.frequency = 'F5' AND dv.recency = 'R5' THEN 'Super Engaged'
          WHEN dv.frequency = 'F4' AND dv.recency = 'R5' THEN 'Highly Engaged'
          WHEN dv.frequency = 'F5' AND dv.recency = 'R4' THEN 'Active Loyalist'
          WHEN dv.frequency = 'F4' AND dv.recency = 'R4' THEN 'Engaged Regular'
          WHEN dv.frequency = 'F3' AND dv.recency IN ('R4','R5') THEN 'Regular w/Potential'
          WHEN dv.frequency IN ('F4','F5') AND dv.recency = 'R3' THEN 'At-Risk Regular'
          WHEN dv.frequency = 'F3' AND dv.recency = 'R3' THEN 'Moderate Engager'
          WHEN dv.frequency IN ('F1','F2') AND dv.recency = 'R4' THEN 'Relatively New Buyer'
          WHEN dv.frequency = 'F1' AND dv.recency = 'R5' THEN 'New Buyer'
          WHEN dv.frequency = 'F2' AND dv.recency = 'R5' THEN 'New Active Buyer'
          WHEN dv.frequency IN ('F2','F3') AND dv.recency IN ('R1','R2') THEN 'Lapsed Buyer'
          WHEN dv.frequency = 'F1' AND dv.recency = 'R1' THEN 'Inactive'
          WHEN dv.frequency IN ('F4','F5') AND dv.recency = 'R1' THEN 'Lost Buyer'
          WHEN dv.frequency = 'F1' AND dv.recency IN ('R2','R3') THEN 'Losing 1-Time Buyer'
          WHEN dv.frequency = 'F2' AND dv.recency = 'R3' THEN 'Nurture Potential'
          WHEN dv.frequency IN ('F4','F5') AND dv.recency = 'R2' THEN 'Inactive Regular'
          ELSE 'Unclassified'
        END                                AS customer_classification
    FROM d_customerupdatesview       AS dv
),

-- 5. Hard-coded customer groups via UNION ALL
customer_group_cte AS (
    SELECT 4 AS customer_group_id, 'Law Enforcement'  AS customer_group_code UNION ALL
    SELECT 2,                   'Wholesale'         UNION ALL
    SELECT 1,                   'General'           UNION ALL
    SELECT 0,                   'NOT LOGGED IN'     UNION ALL
    SELECT 3,                   'Retailer'
),

-- 6. Customer-entity join to pick up group_id
customer_entity_cte AS (
    SELECT 
      email           AS customer_email,
      group_id        AS customer_group_id
    FROM {{ source('magento','customer_entity') }}
)

-- Final join & filter
SELECT
    s.*,
    COALESCE(cg.customer_group_code, 'Not Registered') AS customer_group
FROM Segmentation            AS s
LEFT JOIN customer_entity_cte AS ce 
  ON s.customer_email = ce.customer_email
LEFT JOIN customer_group_cte  AS cg 
  ON ce.customer_group_id = cg.customer_group_id
WHERE s.customer_classification <> ''
