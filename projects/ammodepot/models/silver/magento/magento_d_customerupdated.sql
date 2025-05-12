{{
  config(
    materialized='view',
    schema='silver'
  )
}}

WITH CleanedEmails AS (
    SELECT 
        LOWER(COALESCE(NULLIF(CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) AS CUSTOMER_EMAIL
    FROM {{ source('magento', 'sales_order') }}
),

DistinctEmails AS (
    SELECT DISTINCT CUSTOMER_EMAIL
    FROM CleanedEmails
)

SELECT 
    CUSTOMER_EMAIL,
    ROW_NUMBER() OVER (ORDER BY CUSTOMER_EMAIL) AS RANK_ID
FROM DistinctEmails
