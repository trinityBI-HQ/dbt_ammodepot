Create or Replace View f_sales AS 
//Start Code Conversions Fishbowl Magento

WITH Magento_Identities AS (
    SELECT
        CASE
            WHEN f.value:value IS NOT NULL AND f.value:value != '' THEN f.value:value::STRING
            ELSE NULL
        END AS magento_order_item_identity,
        a.id AS code
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.SO a,
        LATERAL FLATTEN(input => PARSE_JSON(a.CUSTOMFIELDS)) f
    WHERE
        f.value:name = 'Magento Order Identity 1'
),

Conversion AS (
    SELECT 
        f.recordId as IDFB,
        f.CHANNELID as MGNTID
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.PLUGININFO f
    WHERE
        f.TABLENAME = 'SOItem'
),

Conversion1 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.PLUGININFO f
    WHERE
        f.TABLENAME = 'Product'
),

Conversion2 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.PLUGININFO f
    WHERE
        f.TABLENAME = 'SO'
),
//END Code Conversions Fishbowl Magento

//Start - Real Cost and Estimated Cost Segregation By Magento Correspondency (Magento Sales Order Item ID 1 or more codes duplicated)

COST_TEST AS (
    SELECT 
        z.totalcost as COST,
        m.magento_order_item_identity as MAGENTO_ORDER,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,
        child.MGNTID AS SALES_ORDER_ITEM_MAGENTO,
        z.id AS ID_SOItem,
        z.soid AS ORDER_FISHBOWL_ID
    FROM 
        AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM z
    LEFT JOIN
        CONVERSION child ON z.id = child.idfb
    LEFT JOIN
        CONVERSION1 t ON z.productid = t.PRODUTOFISH
    LEFT JOIN
        Magento_Identities m ON z.SOID = m.code
),
// Magento Correspondency (Magento Sales Order Item ID 1 or more codes duplicated)
Aggregation AS (
    SELECT 
        SALES_ORDER_ITEM_MAGENTO AS ID,
        COUNT(*) AS Count_of_ID_MAGENTO,
        MAX(ORDER_FISHBOWL_ID) AS ORDER_FB
    FROM 
        COST_TEST
    GROUP BY 
        SALES_ORDER_ITEM_MAGENTO
    ORDER BY 
        Count_of_ID_MAGENTO DESC
),
//Start - Conversion of Exécted Cost
TOUOMTEST AS (
    SELECT * 
    FROM AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION z
    WHERE z.touomid = 1
),

PRODUCTCODE AS (
    SELECT  
        ty.id AS ID_PRODUTO,
        z.Multiply AS CONVERSION,
        COALESCE(y.avgcost * z.multiply, y.avgcost) AS AVERAGECOST,
        y.avgcost AS COSTNOCONVERSION
    FROM 
        AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT ty
    LEFT JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.PARTCOST y ON ty.partid = y.partid
    LEFT JOIN 
        TOUOMTEST z ON UOMID= z.FROMUOMID
),
//End of Expected Cost
ObjectKIT AS (
select * FROM AD_AIRBYTE.AIRBYTE_SCHEMA.OBJECTTOOBJECT WHERE typeid = 30),

//End of Expected Cost

//Start of KITID Conversion
Aggregation5 AS (
    SELECT 
        
          Sum(z.totalcost)
         as COST,
         obk.recordid2 AS KITID,
        SUM(y.averagecost) AS COSTPROCESSING,
        MAX(QTYORDERED) AS MAXQTYTEST

        
    
    FROM 
        AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM z
    LEFT JOIN
        PRODUCTCODE y ON z.productid = y.id_produto
    LEFT JOIN 
     objectkit obk ON z.id = obk.recordid1 
    WHERE 
        z.typeid = '10' AND z.description NOT LIKE '%POLLYAMOBAG%'
    GROUP BY
         obk.recordid2
),


Cost_Fishbowl AS (
    SELECT 
        CASE 
            WHEN z.totalcost = 0 THEN zy.cost
            ELSE z.totalcost 
        END as COST,
        m.magento_order_item_identity as MAGENTO_ORDER,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,
        child.MGNTID AS ID_MAGENTO,
        z.id AS ID_SOItem,
        z.soid AS ORDER_FISHBOWL_ID,
        f.Count_of_ID_MAGENTO AS Count_of_ID_MAGENTO,
        z.productid AS ID_PRODUTO_FISHBOWL,
        ty.kitflag AS BUNDLE,
       COALESCE(COALESCE(zy.COSTPROCESSING, tz.AverageCOST),tz.averageCOST) AS AverageWeightedCost,
        z.datescheduledfulfillment as DATESCHEDULEFULFILLMENT,
        z.qtyfulfilled as qty
    FROM 
        AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM z
    LEFT JOIN 
        CONVERSION child ON z.id = child.idfb
    LEFT JOIN 
        PRODUCTCODE tz ON z.productid = tz.ID_PRODUTO
    LEFT JOIN 
        CONVERSION1 t ON z.productid = t.PRODUTOFISH
    LEFT JOIN 
        Magento_Identities m ON z.SOID = m.code
    LEFT JOIN 
        AGGREGATION f ON child.MGNTID = f.ID
    LEFT JOIN 
        AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT ty ON z.productid = ty.id
    LEFT JOIN 
        AGGREGATION5 zy ON z.id = zy.kitid


),
//END of KITID Conversion
//END - Real Cost and Estimated Cost Segregation By Magento Correspondency (Magento Sales Order Item ID 1 or more codes duplicated)

//START - Last Day cost registered in Fishbowl
Last_Day_Cost AS (
    SELECT 
        z.ID_PRODUTO_FISHBOWL AS PRODUCT_ID,
        MAX(z.DATESCHEDULEFULFILLMENT) AS LAST_SCHEDULED_DATE
    FROM 
       Cost_Fishbowl z
       WHERE 
        z.COST IS NOT NULL AND z.COST > 0
    GROUP BY 
        z.ID_PRODUTO_FISHBOWL
        
),

Filtered_Cost AS (
    SELECT 
        z.ID_PRODUTO_FISHBOWL AS PRODUCT_ID,
        AVG(div0(z.COST,z.qty)) AS COST
    FROM 
       Cost_Fishbowl z
    JOIN 
        Last_Day_Cost ld ON TO_VARCHAR(z.ID_PRODUTO_FISHBOWL) = TO_varchar(ld.PRODUCT_ID) AND z.DATESCHEDULEFULFILLMENT = ld.LAST_SCHEDULED_DATE
    WHERE 
        z.Cost IS NOT NULL AND z.Cost > 0
      Group By 
      z.ID_PRODUTO_FISHBOWL
      
),






Cost_Fishbowl1 AS (
    SELECT 
        COALESCE(NULLIF(z.totalcost, 0), NULLIF(zy.cost, 0), cty.cost * z.qtyordered) AS cost,
        z.totalcost AS TOTALCOST,
        zy.cost AS COSTBUNDLE,
        m.magento_order_item_identity AS MAGENTO_ORDER,
        cty.cost AS COSTFILTERED,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,
        child.MGNTID AS ID_MAGENTO,
        z.id AS ID_SOItem,
        z.soid AS ORDER_FISHBOWL_ID,
        f.Count_of_ID_MAGENTO AS Count_of_ID_MAGENTO,
        z.productid AS ID_PRODUTO_FISHBOWL,
        ty.kitflag AS BUNDLE,
        COALESCE(COALESCE(zy.COSTPROCESSING, tz.AverageCOST), tz.averageCOST) AS AverageWeightedCost,
        z.datescheduledfulfillment AS DATESCHEDULEFULFILLMENT,
        z.qtyfulfilled AS qty
    FROM 
        AD_AIRBYTE.AIRBYTE_SCHEMA.SOITEM z
    LEFT JOIN 
        CONVERSION child ON z.id = child.idfb
    LEFT JOIN 
        PRODUCTCODE tz ON z.productid = tz.ID_PRODUTO
    LEFT JOIN 
        CONVERSION1 t ON z.productid = t.PRODUTOFISH
    LEFT JOIN 
        Magento_Identities m ON z.SOID = m.code
    LEFT JOIN 
        AGGREGATION f ON child.MGNTID = f.ID
    LEFT JOIN 
        AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT ty ON z.productid = ty.id
    LEFT JOIN 
        AGGREGATION5 zy ON z.id = zy.kitid
    LEFT JOIN 
        Filtered_COST cty ON TO_VARCHAR(z.productid) = TO_VARCHAR(cty.PRODUCT_ID)
    
)

,
//END - Last Day cost registered in Fishbowl



//START - Creating the Different Keys Fishbowl Magento Integration
COST1 AS (
    SELECT *
    FROM
        Cost_Fishbowl1 y
    LEFT JOIN
        Aggregation f ON y.ID_MAGENTO = f.ID 
    WHERE f.Count_of_ID_MAGENTO = 1
),

COST2 AS (SELECT
    AVG(y.cost) AS COST,
    y.ID_MAGENTO,
    AVG(y.AverageWeightedCost) AS AverageWeightedCost,
    y.ID_PRODUTO_MAGENTO

    FROM
        Cost_Fishbowl1 y
    LEFT JOIN
        Aggregation f ON y.ID_MAGENTO = f.ID 
    WHERE f.Count_of_ID_MAGENTO > 1
  Group BY y.id_magento, id_Produto_magento

),

COST3 AS (
    SELECT 
        AVG(COST) AS COST,
        AVG(AverageWeightedCost)AS AverageWeightedCost,
        ID_MAGENTO
    FROM 
        COST2
    LEFT JOIN
        AD_AIRBYTE.TEST_DTO_2.SALES_ORDER_ITEM z ON ID_MAGENTO = z.item_id
    WHERE z.ROW_TOTAL <> 0
    Group By 
    ID_MAGENTO
),

STATUSProcessing AS (
    SELECT
        z.order_id AS order_id,
        SUM(COALESCE(f.COST, y.COST)) AS COST,
        SUM(COALESCE(f.AverageWeightedCost, y.AverageWeightedCost)) AS COST_AVERAGE_ORDER
    FROM
        AD_AIRBYTE.TEST_DTO_2.SALES_ORDER_ITEM z
    LEFT JOIN
        COST1 f ON z.item_id = f.ID_MAGENTO
    LEFT JOIN
        COST2 y ON concat(z.item_id, '@', z.product_id) = concat(y.ID_MAGENTO, '@', y.ID_PRODUTO_MAGENTO)
    GROUP BY 
        z.order_id
),
//END - Creating the Different Keys Fishbowl Magento Integration
//START - First Interaction - Fishbowl Magento
Interaction AS (
SELECT 
    to_timestamp_ntz(CONVERT_TIMEZONE( 'America/New_York', z.created_at)) AS CREATED_AT,
    z.product_id AS product_id,
    z.order_id AS order_id,
    div0(z.qty_ordered*z.row_total,z.row_total) AS qty_ordered,
    z.discount_invoiced AS discount_invoiced,
    concat(z.product_id, '@', z.order_id) AS CHAVE,
    COALESCE(f.COST, y.COST,tz.cost,f.AverageWeightedCost*z.qty_ordered, y.AverageWeightedCost*z.qty_ordered,tz.averageweightedcost*z.qty_ordered)  as COST,
    COALESCE(f.AverageWeightedCost, y.AverageWeightedCost,tz.averageweightedcost) AS AverageWeightedCost,
    z.tax_amount AS tax_amount,
    z.row_total - coalesce(z.AMOUNT_REFUNDED,0) - coalesce(z.discount_amount,0) + coalesce(z.discount_refunded,0) AS ROW_TOTAL,
    t.increment_ID,
    t.BILLING_ADDRESS_ID as BILLING_ADDRESS_ID,
    t.customer_email as customer_email,
    child.postcode as postcode,
    child.country_id as COUNTRY,
    child.region as REGION,
    child.city as CITY,
    child.street as Street,
    child.telephone as telephone,
    Concat(t.CUSTOMER_FIRSTNAME,' ', t.CUSTOMER_LASTNAME) as Customer_NAME,
    z.base_cost as COST_MAGENTO,
    z.item_id as ID,
    t.status as STATUS,
    p.COST as ORDERCOST,
    p.COST_AVERAGE_ORDER AS FISHBOWL_REGISTEREDCOST,
    z.store_id AS STORE_ID,
    t.store_name AS STORE_NAME,
    z.weight,
    f.cost AS COST1,
     y.cost AS COST2,
     tz.cost AS COST3,
     f.averageweightedcost AS AVERAGE1,
    y.AverageWeightedCost AS AVERAGE2,
     tz.averageweightedcost AS AVERAGE3,
     z.product_options,
    z.product_type,
    z.parent_item_id,
    z.sku as TESTSKU,
    z.additional_data,
    z.applied_rule_ids,
    z.vendor,
    t.customer_id


    
FROM
    AD_AIRBYTE.TEST_DTO_2.SALES_ORDER_ITEM z
LEFT JOIN 
   AD_AIRBYTE.TEST_DTO_2.SALES_ORDER t ON z.order_id = t.entity_ID
LEFT JOIN 
   AD_AIRBYTE.TEST_DTO_2.SALES_ORDER_ADDRESS child ON t.BILLING_ADDRESS_ID = child.entity_id
LEFT JOIN 
    COST1 f ON z.item_id = f.ID_MAGENTO
LEFT JOIN 
    COST2 y ON concat(z.item_id, '@', z.product_id) = concat(y.ID_MAGENTO, '@', y.ID_PRODUTO_MAGENTO)
LEFT JOIN 
    COST3 tz ON z.item_id = tz.ID_MAGENTO

LEFT JOIN 
    STATUSPROCESSING p ON z.order_id = p.order_id),
    
//END - First Interaction - Fishbowl Magento  
 //START - Last Day cost registered in All  
 Last_Day_Cost1 AS (
    SELECT 
        to_varchar(z.product_ID) AS PRODUCT_ID,
        MAX(z.created_at) AS LAST_SCHEDULED_DATE
    FROM 
        interaction z
    WHERE 
        z.COST > 0 AND z.qty_ordered > 0
    GROUP BY 
        z.product_ID
),
FILTERED_COST2 AS (
    SELECT 
        z.product_ID,
        z.COST,
        z.qty_ordered as QTY,
        z.created_at
    FROM 
        interaction z
    INNER JOIN 
        Last_Day_Cost1 ldc1
    ON 
        to_VARCHAR(z.product_ID) = TO_VARCHAR(ldc1.PRODUCT_ID) AND z.created_at = ldc1.LAST_SCHEDULED_DATE
    WHERE 
        z.COST > 0 AND z.qty_ordered > 0
),
FILTERED_COST1 AS (
    SELECT 
        z.product_ID,
       SUM(z.COST) AS COST,
        SUM(z.qty) as QTY,
        z.created_at
    FROM 
        FILTERED_COST2 z
    GROUP BY
z.product_ID, z.created_at

),

 //END - Last Day cost  registered in All 

 //START - Freight Allocation in product by Weight Inside Order
NEWSHIP AS (

SELECT Sum(Net_amount) AS NET_AMOUNT,
tracking_number as TRACKING_NUMBER

FROM
PC_FIVETRAN_DB.UPS_INVOICE_HISTORY.UPS_INVOICE
GROUP BY
TRACKING_NUMBER
),


SHIPTRANSFORMATION AS (
    SELECT z.SOID AS SOID,
    COALESCE(SUM(nw.net_amount),SUM(t.freightamount)) as FREIGHTAMOUNT,
    SUM(t.freightweight) as FREIGHTWEIGHT,
    AVG(z.carrierserviceid) as CARRIERSERVICEID,
    SUM(nw.net_amount) AS AmountUPS,
    COUNT(t.trackingnum) AS PACKAGENUMB

    FROM AD_AIRBYTE.AIRBYTE_SCHEMA.SHIP z
    LEFT JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.SHIPCARTON t ON z.id = t.SHIPID
    LEFT JOIN NEWSHIP nw ON t.trackingnum = nw.tracking_number

    GROUP BY z.soid
),


FreightInfo AS (
SELECT 
ty.PRODUTO_MAGENTO as Order_magento,
AVG(t.freightamount) as freightamount,
AVG(t.freightweight) as freightweight,
AVG(t.carrierserviceid) as CARRIERSERVICEID

FROM 
AD_AIRBYTE.AIRBYTE_SCHEMA.SO z
LEFT JOIN
SHIPTRANSFORMATION t on TO_VARCHAR(z.id) = TO_VARCHAR(t.SOID)
LEFT JOIN
Conversion2 ty on z.id = ty.PRODUTOFISH
GROUP BY
ty.Produto_MAGENTO),

ORDERNOZERO AS (
    SELECT 
         z.weight                              AS WEIGHT
        ,z.order_id                            AS ORDER_ID
        ,z.sku
        ,z.product_id
        ,z.qty_ordered                        AS qty_ordered
        ,div0(z.qty_ordered * z.row_total, z.row_total) AS TEST
        ,z.row_total
           - COALESCE(z.amount_refunded, 0)
           - COALESCE(z.discount_amount, 0)
           + COALESCE(z.discount_refunded, 0)
         AS row_total
    FROM AD_AIRBYTE.TEST_DTO_2.sales_order_item z
    LEFT JOIN AD_AIRBYTE.TEST_DTO_2.catalog_product_entity ct 
           ON z.product_id = ct.entity_id
    WHERE 
          -- Make sure the row_total portion isn't dividing by zero 
          div0(
              (z.row_total 
               - COALESCE(z.amount_refunded,0) 
               - COALESCE(z.discount_amount,0) 
               + COALESCE(z.discount_refunded,0))
               * z.qty_ordered,
              (z.row_total 
               - COALESCE(z.amount_refunded,0) 
               - COALESCE(z.discount_amount,0) 
               + COALESCE(z.discount_refunded,0))
          ) <> 0
      -- Exclude any SKU containing "Parcel Defender" in any combination of upper/lower case 
      AND ct.sku NOT ILIKE '%parceldefender%'
),

WeightOrder AS (
SELECT 
SUM(z.weight) as WEIGHT,
z.order_id as ORDER_ID,
COUNT(z.product_Id) AS Products
FROM
ORDERNOZERO z

GROUP BY
z.order_id
),

F_SHIP AS(

SELECT 
SUM(ty.shipping_amount) as shipping_amount,
SUM(ty.base_shipping_amount) as base_shipping_amount,
SUM(ty.base_shipping_canceled) as base_shipping_canceled,
SUM(ty.base_shipping_discount_amount) AS base_shipping_discount_amount,
SUM(ty.base_shipping_refunded) AS base_shipping_refunded,
SUM(ty.base_shipping_tax_amount) as base_shipping_tax_amount,
SUM(ty.base_shipping_tax_refunded) AS base_shipping_tax_refunded,
SUM(Coalesce(ty.BASE_SHIPPING_AMOUNT,0) -coalesce(ty.BASE_SHIPPING_TAX_AMOUNT,0) - Coalesce(ty.BASE_SHIPPING_REFUNDED,0) +Coalesce(ty.BASE_SHIPPING_TAX_REFUNDED,0)) AS NETSALES,
ty.entity_id AS ORDER_ID,
SUM(zy.freightamount) as Freightamount

FROM
AD_AIRBYTE.TEST_DTO_2.SALES_ORDER ty 
LEFT JOIN
FreightInfo zy ON TO_VARCHAR(ty.entity_id) = TO_VARCHAR(zy.order_magento)
Group BY 
ty.entity_id
),


Product_Sales AS (
    SELECT
        s.ITEM_ID,
        SUM(s.qty_ordered * COALESCE(uom.multiply, 1)) AS Part_Qty_Sold,
        AVG(UOM.multiply) AS CONVERSION,
        cpe.sku AS SKU


    FROM
       AD_AIRBYTE.TEST_DTO_2.SALES_ORDER_ITEM s
  

    JOIN
        AD_AIRBYTE.TEST_DTO_2.SALES_ORDER o ON s.order_id = o.entity_id
    JOIN
       AD_AIRBYTE.AIRBYTE_SCHEMA.CATALOG_PRODUCT_ENTITY cpe ON s.product_id = cpe.entity_id
    JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT pr ON cpe.sku = pr.num

    JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.PART p ON pr.partid = p.id
    LEFT JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1
          WHERE s.product_type <> 'bundle'
        AND s.price > 0

    GROUP BY
     s.ITEM_ID,cpe.sku
    ORDER BY
        SUM(s.row_invoiced) DESC
),



SKUBASE AS (
SELECT 
    to_date( Z.created_at) AS CREATED_AT,
    z.created_at AS TIMEDATE,
    DATE_TRUNC('HOUR', z.created_at) as tIniciodaHoraCopiar,
    Z.product_id AS PRODUCT_ID,
    Z.order_id AS ORDER_ID,
    div0(Z.qty_ordered * Z.row_total, Z.row_total) AS QTY_ORDERED,
     z.qty_ordered AS ORDERED,
    Z.discount_invoiced AS DISCOUNT_INVOICED,
    concat(Z.product_id, '@', Z.order_id) AS CHAVE,
    CASE WHEN z.qty_ordered > 0 THEN z.cost ELSE null END AS COST,
    z.AverageWeightedCost AS AVERAGE_WEIGHTED_COST,
    Z.tax_amount AS TAX_AMOUNT,
    Z.row_total AS ROW_TOTAL,
    z.increment_ID AS INCREMENT_ID,
    z.BILLING_ADDRESS_ID AS BILLING_ADDRESS_ID,
    z.customer_email AS CUSTOMER_EMAIL,
    z.postcode AS POSTCODE,
    z.country AS COUNTRY,
    z.region AS REGION,
    z.city AS CITY,
    z.STREET as STREET,
    z.telephone AS TELEPHONE,
    z.customer_name AS CUSTOMER_NAME,
    Z.ID AS ID,
    UPPER(z.status) AS STATUS,
    z.COST AS ORDER_COST,
    z.FISHBOWL_REGISTEREDCOST AS FISHBOWL_REGISTERED_COST,
    Z.store_id AS STORE_ID,
    z.store_name AS STORE_NAME,
    Z.weight AS WEIGHT,
    div0(z.weight, ctm.weight) AS Percentage,
    ctm.weight AS WeightORDER,
    CASE WHEN CTM.weight IS NULL AND z.testsku NOT ILIKE '%parceldefender%' THEN div0null(div0(z.qty_ordered * z.row_total, z.row_total) * ty.netsales, ctm.products * div0(z.qty_ordered * z.row_total, z.row_total)) ELSE div0null(z.weight * div0(z.qty_ordered * z.row_total, z.row_total) * ty.netsales, ctm.weight * div0(z.qty_ordered * z.row_total, z.row_total)) END AS FREIGHT_REVENUE,
    CASE WHEN CTM.weight IS NULL AND z.testsku NOT ILIKE '%parceldefender%' THEN div0null(div0(z.qty_ordered * z.row_total, z.row_total) , ctm.products * div0(z.qty_ordered * z.row_total, z.row_total))* Freightamount ELSE div0null(z.weight * div0(z.qty_ordered * z.row_total, z.row_total) , ctm.weight * div0(z.qty_ordered * z.row_total, z.row_total))* Freightamount END AS FREIGHT_COST,
    z.cost1,
    z.cost2,
    z.cost3,
    z.average1,
    z.average2,
    z.average3,
    ctw.Part_Qty_Sold,
    Coalesce(ctw.Conversion, 1) AS Conversion,
    to_time(DATE_TRUNC('HOUR', z.created_at)) AS tIniciodaHora,
    z.created_at AS TrickAT,
    z.product_options,
    z.product_type,
    z.parent_item_id,
    z.TESTSKU as TESTSKU,
     z.vendor,
     z.customer_id,
     ty.netsales AS FRSALES,
    ty.freightamount AS FCOST

FROM
    interaction z
    LEFT JOIN F_SHIP ty ON TO_VARCHAR(z.order_id) = TO_VARCHAR(ty.order_id)
    LEFT JOIN Product_Sales ctw ON z.id = ctw.ITEM_ID
    LEFT JOIN Filtered_COST1 zyt ON TO_VARCHAR(z.product_id) = TO_VARCHAR(zyt.PRODUCT_ID)
    LEFT JOIN weightorder ctm ON TO_VARCHAR(z.order_id) = TO_VARCHAR(ctm.order_id)


ORDER BY z.created_at DESC
),

ToTRANSFER AS ( 
SELECT 
Id AS ID,
Row_total,
Cost, 
FREIGHT_REVENUE,
FREIGHT_cost,
qty_ordered,
Part_Qty_Sold

FROM 
SKUBASE
WHERE 
product_type = 'configurable'),



LAST AS (SELECT 
z.CREATED_AT,
z.TIMEDATE,
z.id AS ID,
z.increment_id,
z.tIniciodaHoraCopiar AS tIniciodaHoraCopiar,
z.PRODUCT_ID,
z.ORDER_ID,
z.created_at AS TrickAT,
z.product_options,
z.product_type,
z.parent_item_id,
z.TESTSKU as TESTSKU,
z.conversion,
z.tIniciodaHora AS tIniciodaHora,
z.customer_email AS CUSTOMER_EMAIL,
z.postcode AS POSTCODE,
z.country AS COUNTRY,
z.region AS REGION,
z.city AS CITY,
z.street AS STREET,
z.telephone AS TELEPHONE,
z.customer_name AS CUSTOMER_NAME,
Z.store_id AS STORE_ID,
z.status AS STATUS,
z.vendor,
z.customer_id,
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.Row_total ELSE z.row_total END AS ROW_TOTAL,  
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.COST ELSE z.COST END AS COST,
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.qty_ordered ELSE z.qty_Ordered END AS QTY_ORDERED,
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.Part_Qty_Sold ELSE z.Part_Qty_Sold END AS Part_Qty_Sold,  
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.Freight_revenue ELSE z.freight_revenue END AS freight_revenue,
CASE WHEN ty.ID IS NOT NULL THEN 
Ty.Freight_cost ELSE z.freight_cost END AS freight_cost ,
ty.cost as TESTC,
ty.row_total as TestR,
ty.freight_revenue as TestFR,
ty.Freight_Cost as TESTFC


FROM
SKUBASE z
LEFT JOIN
ToTransfer ty ON z.parent_ITEM_ID = ty.id 

),

Last_Day_Cost4 AS (
    SELECT 
        to_varchar(z.product_ID) AS PRODUCT_ID,
        MAX(z.TrickAT) AS LAST_SCHEDULED_DATE
    FROM 
        last z
    WHERE 
        z.COST > 0 AND z.qty_ordered > 0
    GROUP BY 
        z.product_ID
),
FILTERED_COST5 AS (
    SELECT 
        z.product_ID,
        z.COST,
        z.qty_ordered as QTY,
        z.TrickAT
    FROM 
        last z
    INNER JOIN 
        Last_Day_Cost4 ldc1
    ON 
        to_VARCHAR(z.product_ID) = TO_VARCHAR(ldc1.PRODUCT_ID) AND z.TrickAT = ldc1.LAST_SCHEDULED_DATE
    WHERE 
        z.COST > 0 AND z.qty_ordered > 0
),
FILTERED_COST3 AS (
    SELECT 
        z.product_ID,
       DIV0(SUM(z.COST),SUM(z.qty)) AS COST,
        SUM(z.qty) as QTY,
        z.TrickAT
    FROM 
        FILTERED_COST5 z
    GROUP BY
z.product_ID, z.trickat

)

SELECT 
z.CREATED_AT,
z.TIMEDATE,
z.id AS ID,
z.increment_id,
z.tIniciodaHoraCopiar AS "Início da Hora - Copiar",
z.PRODUCT_ID,
z.ORDER_ID,
z.created_at AS TrickAT,
z.product_options,
z.product_type,
z.parent_item_id,
z.TESTSKU as TESTSKU,
z.conversion,
z.tIniciodaHora AS "Início da Hora",
z.customer_email AS CUSTOMER_EMAIL,
z.postcode AS POSTCODE,
z.country AS COUNTRY,
z.region AS REGION,
z.city AS CITY,
z.STREET as STREET,
z.telephone AS TELEPHONE,
z.customer_name AS CUSTOMER_NAME,
Z.store_id AS STORE_ID,
z.status AS STATUS,
z.ROW_TOTAL,  
COALESCE(z.COST, zyt.cost*z.qty_ordered) as COST,
z.QTY_ORDERED,  
z.freight_revenue,
z.freight_cost ,
z.TESTC,
z.TestR,
z.TestFR,
z.TESTFC,
 z.vendor,
 z.customer_id,
upt.rank_id,
Coalesce(z.Part_Qty_Sold,z.qty_ordered) AS Part_Qty_Sold

FROM
LAST z
 LEFT JOIN Filtered_COST3 zyt ON TO_VARCHAR(z.product_id) = TO_VARCHAR(zyt.PRODUCT_ID)
LEFT JOIN
AD_AIRBYTE.TEST_DTO_2.d_customerupdated upt ON  LOWER(COALESCE(NULLIF(z.CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) = upt.customer_email


WHERE
z.product_type <> 'configurable' 

