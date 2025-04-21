{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (
    SELECT 
        id,
        soid,
        productid,
        description,
        qtyordered,
        qtyfulfilled,
        qtyshipped,
        unitprice,
        totalprice,
        totalcost,
        typeid,
        datescheduledfulfillment,
        customfields,
        itemnote,
        taxrateid,
        uomid,
        qtypicked,
        datecreated,
        datelastmodified
    FROM 
        {{ source('fishbowl', 'soitem') }}
    WHERE 
        _ab_cdc_deleted_at IS NULL
)

SELECT 
    id AS so_item_id,
    soid AS so_id,
    productid AS product_id,
    description AS item_description,
    qtyordered AS quantity_ordered,
    qtyfulfilled AS quantity_fulfilled,
    qtyshipped AS quantity_shipped,
    unitprice AS unit_price,
    totalprice AS total_price,
    totalcost AS total_cost,
    typeid AS type_id,
    datescheduledfulfillment AS date_scheduled_fulfillment,
    customfields AS custom_fields,
    itemnote AS item_note,
    taxrateid AS tax_rate_id,
    uomid AS uom_id,
    qtypicked AS quantity_picked,
    datecreated AS date_created,
    datelastmodified AS date_last_modified
FROM 
    source_data
