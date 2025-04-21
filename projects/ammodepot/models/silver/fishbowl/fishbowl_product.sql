{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        id,
        partid,
        num,
        description,
        price,
        typeid,
        activeflag,
        uomid,
        weight,
        weightuomid,
        sizeuomid,
        upccode,
        datecreated,
        datelastmodified,
        details,
        productclassid,
        customfields
    FROM 
        {{ source('fishbowl', 'product') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS product_id,
    partid AS part_id,
    num AS sku,
    description AS product_description,
    price AS product_price,
    typeid AS product_type_id,
    activeflag AS is_active,
    uomid AS uom_id,
    weight AS product_weight,
    weightuomid AS weight_uom_id,
    sizeuomid AS size_uom_id,
    upccode AS upc_code,
    datecreated AS date_created,
    datelastmodified AS date_last_modified,
    details AS product_details,
    productclassid AS product_class_id,
    customfields AS custom_fields
FROM 
    source_data
