{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        store_id,
        name,
        code,
        group_id,
        website_id,
        is_active,
        sort_order,
        _ab_cdc_deleted_at

    FROM
        {{ source('magento', 'store') }}
    WHERE
        _ab_cdc_deleted_at IS NULL
)

SELECT
    store_id AS store_id,
    name AS store_name,
    code AS store_code,
    group_id AS group_id,
    website_id AS website_id,
    CAST(is_active AS BOOLEAN) AS is_active,
    sort_order AS sort_order

FROM
    source_data