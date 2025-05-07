{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        entity_id,
        attribute_set_id,
        type_id,
        sku,
        has_options,
        required_options,
        created_at,
        updated_at
    FROM 
        {{ source('magento', 'catalog_product_entity') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    entity_id AS product_entity_id,
    attribute_set_id,
    type_id,
    sku,
    CAST(has_options AS BOOLEAN) AS has_options,
    CAST(required_options AS BOOLEAN) AS required_options,
    created_at,
    updated_at
FROM 
    source_data
