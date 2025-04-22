{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT
        tracking_number,
        net_amount
    FROM {{ source('magento', 'ups_invoice') }}
)

SELECT
    tracking_number,
    net_amount
FROM source_data
