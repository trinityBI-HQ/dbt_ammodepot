-- snowflake views

create or replace view AD_AIRBYTE.AD_REALTIME.D_CUSTOMERUPDATED(
	CUSTOMER_EMAIL,
	RANK_ID
) as 
WITH CleanedEmails AS (
    SELECT 
        LOWER(COALESCE(NULLIF(CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) AS CUSTOMER_EMAIL
    FROM 
        AD_MAGENTO.SALES_ORDER
),
DistinctEmails AS (
    SELECT DISTINCT 
        CUSTOMER_EMAIL
    FROM 
        CleanedEmails
)
SELECT 
    CUSTOMER_EMAIL,
    ROW_NUMBER() OVER (ORDER BY CUSTOMER_EMAIL) AS RANK_ID
FROM 
    DistinctEmails;

create or replace view AD_AIRBYTE.AD_REALTIME.D_PRODUCT_REALTIME(
	"Product ID",
	SKU,
	"Product Name",
	"General Purpose",
	"Product URL",
	"Product Image URL",
	"Vendor",
	"Discontinued",
	"Parent SKU",
	GROUPED_SKU,
	"Boxes/Case",
	"Caliber",
	"Manufacturer SKU",
	UPC,
	"Manufacturer",
	"Projectile",
	"Unit Type",
	"Rounds/Package",
	"Attribute Set",
	"Categories",
	"Gun Type",
	"DD Caliber",
	"DD Gun Action",
	"DD Condition",
	"DD Gun Parts",
	"Capacity",
	"Material",
	"Primary Category",
	"DD Color",
	"Optic Coating",
	"DD Weapons Platform",
	"Thread Pattern",
	"Thread Type",
	"Model",
	CONVERT,
	AVGCOST,
	LASTVENDORCOST
) as
WITH attribute_id_cte AS (
    SELECT attribute_id, attribute_code
    FROM ad_magento.eav_attribute
    WHERE attribute_code IN (
        'name', 'url_key', 'manufacturer_sku', 'upc', 'image', 'cost', 'price', 'status', 'visibility', 'weight', 
        'manufacturer', 'attribute_set_name', 'brand_type', 'grain_weight', 'unit_type', 'projectile', 'caliber', 
        'boxes_case', 'rounds_package', 'suggested_use', 'gun_type', 'ddcaliber', 'capacity', 
        'ddaction', 'ddcondition', 'material', 'ddgun_parts', 'primary_category', 'ddcolor', 'optic_coating', 'ddweapons_platform',
        'thread_pattern', 'thread_type', 'model' -- Added new attribute 'model'
    )
),
Test1 AS (
SELECT
* FROM
ad_magento.catalog_product_entity_int
),

varchar_attributes AS (
    SELECT cpv.entity_id, ac.attribute_code, cpv.value
    FROM ad_magento.catalog_product_entity_varchar cpv
    JOIN attribute_id_cte ac ON cpv.attribute_id = ac.attribute_id
    WHERE cpv.store_id = 0
),
text_attributes AS (
    SELECT cpt.entity_id, ac.attribute_code, cpt.value
    FROM ad_magento.catalog_product_entity_text cpt
    JOIN attribute_id_cte ac ON cpt.attribute_id = ac.attribute_id
    WHERE cpt.store_id = 0
),
int_attributes AS (
    SELECT cpi.entity_id, ac.attribute_code, cpi.value
    FROM Test1 cpi
    JOIN attribute_id_cte ac ON cpi.attribute_id = ac.attribute_id
    WHERE cpi.store_id = 0
),
decimal_attributes AS (
    SELECT cpd.entity_id, ac.attribute_code, cpd.value
    FROM ad_magento.catalog_product_entity_decimal cpd
    JOIN attribute_id_cte ac ON cpd.attribute_id = ac.attribute_id
    WHERE cpd.store_id = 0
),
category_data AS (
    SELECT ccp.product_id, LISTAGG(ccv.value, ' > ') WITHIN GROUP (ORDER BY ccv.value) AS categories
    FROM ad_magento.catalog_category_product ccp
    JOIN ad_magento.catalog_category_entity_varchar ccv ON ccp.category_id = ccv.entity_id
    JOIN attribute_id_cte ac ON ccv.attribute_id = ac.attribute_id AND ac.attribute_code = 'name'
    GROUP BY ccp.product_id
),

parent_sku_data AS (
    SELECT sl.product_id, parent.sku AS parent_sku
    FROM ad_magento.catalog_product_super_link sl
    JOIN ad_magento.catalog_product_entity parent ON sl.parent_id = parent.entity_id
),
discontinued_data AS (
    SELECT entity_id,
           CASE WHEN attribute_set_id = 50 THEN 'Yes' ELSE 'No' END AS discontinued
    FROM ad_magento.catalog_product_entity
),
manufacturer_data AS (
    SELECT cpi.entity_id, eov.value AS manufacturer
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 677 AND cpi.store_id = 0
),
projectile_data AS (
    SELECT cpi.entity_id, eov.value AS projectile
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 681 AND cpi.store_id = 0 
),
unit_type_data AS (
    SELECT cpi.entity_id, eov.value AS unit_type
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 649 AND cpi.store_id = 0 
),
ddcaliber_data AS (
    SELECT cpi.entity_id, eov.value AS ddcaliber
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 678 AND cpi.store_id = 0
),
ddaction_data AS (
    SELECT cpi.entity_id, eov.value AS ddaction
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 718 AND cpi.store_id = 0 
),
ddcondition_data AS (
    SELECT cpi.entity_id, eov.value AS ddcondition
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 676 AND cpi.store_id = 0 
),
ddgun_parts_data AS (
    SELECT cpi.entity_id, eov.value AS ddgun_parts
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 817 AND cpi.store_id = 0 
),
rounds_package_data AS (
    SELECT cpv.entity_id, cpv.value AS rounds_package
    FROM ad_magento.catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 152 AND cpv.store_id = 0
),
capacity_data AS (
    SELECT cpv.entity_id, cpv.value AS capacity
    FROM ad_magento.catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 165 AND cpv.store_id = 0
),
vendor_data AS (
    SELECT cpei.entity_id, ev.value AS vendor
    FROM ad_magento.catalog_product_entity_int cpei
    JOIN ad_magento.eav_attribute_option_value ev ON cpei.value = ev.option_id
    WHERE cpei.attribute_id = 145),
material_data AS (
    SELECT cpv.entity_id, cpv.value AS material
    FROM ad_magento.catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 188 AND cpv.store_id = 0
),
attribute_set_data AS (
    SELECT cpe.entity_id, eas.attribute_set_name
    FROM ad_magento.catalog_product_entity cpe
    JOIN ad_magento.eav_attribute_set eas ON cpe.attribute_set_id = eas.attribute_set_id
),
primary_category_data AS (
    SELECT cpi.entity_id, eov.value AS primary_category
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 878 AND cpi.store_id = 0
),
ddcolor_data AS (
    SELECT cpi.entity_id, eov.value AS ddcolor
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 685 AND cpi.store_id = 0
),
optic_coating_data AS (
    SELECT cpt.entity_id, cpt.value AS optic_coating
    FROM ad_magento.catalog_product_entity_text cpt
    JOIN attribute_id_cte ac ON cpt.attribute_id = ac.attribute_id
    WHERE ac.attribute_code = 'optic_coating' AND cpt.store_id = 0
),
ddweapons_platform_data AS (
    SELECT cpi.entity_id, eov.value AS ddweapons_platform
    FROM Test1 cpi
    JOIN ad_magento.eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 756 AND cpi.store_id = 0 
),

vendor_data AS (
    SELECT cpei.entity_id, ev.value AS vendor
    FROM ad_magento.catalog_product_entity_int cpei
    JOIN ad_magento.eav_attribute_option_value ev ON cpei.value = ev.option_id
    WHERE cpei.attribute_id = 145
),
Vendorpartscost AS (
    SELECT
        datelastmodified,
        partid,
        lastcost,
        ROW_NUMBER() OVER (PARTITION BY partid ORDER BY datelastmodified DESC) AS rn
    FROM
        ad_fishbowl.VENDORPARTS
),
VendorLast AS ( 
SELECT
    datelastmodified,
    partid,
    lastcost
FROM
    Vendorpartscost
WHERE
    rn = 1),

Fishbowl_Conversion AS (
SELECT 
    pr.num, 
    AVG(uom.multiply) AS CONVERT,
    AVG(pc.avgcost) AS AVGCOST,
    AVG(vp.lastcost) AS LASTVENDORCOST


FROM
    ad_fishbowl.PRODUCT pr

LEFT JOIN
    ad_fishbowl.UOMCONVERSION uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1

LEFT JOIN
    ad_fishbowl.PARTCOST pc ON pr.partid = pc.partid

LEFT JOIN
    vendorlast vp ON pr.partid = vp.partid



Group BY
pr.num)



SELECT 
    e.entity_id AS "Product ID",
    e.sku,
    MAX(CASE WHEN va.attribute_code = 'name' THEN va.value END) AS "Product Name",
    MAX(CASE WHEN va.attribute_code = 'suggested_use' THEN va.value END) AS "General Purpose",
    MAX(CASE WHEN va.attribute_code = 'url_key' THEN CONCAT('https://www.ammunitiondepot.com/', va.value) END) AS "Product URL",
    MAX(CASE WHEN va.attribute_code = 'image' THEN CONCAT('https://www.ammunitiondepot.com/media/catalog/product', va.value) END) AS "Product Image URL",
    vd.vendor AS "Vendor",
    dd.discontinued AS "Discontinued",
    psd.parent_sku AS "Parent SKU",
    COALESCE(psd.parent_sku,e.sku) AS Grouped_SKU,
    MAX(CASE WHEN va.attribute_code = 'boxes_case' THEN va.value END) AS "Boxes/Case",
    MAX(CASE WHEN va.attribute_code = 'caliber' THEN va.value END) AS "Caliber",
    MAX(CASE WHEN va.attribute_code = 'manufacturer_sku' THEN va.value END) AS "Manufacturer SKU",
    MAX(CASE WHEN va.attribute_code = 'upc' THEN va.value END) AS "UPC",
    MAX(md.manufacturer) AS "Manufacturer",
    MAX(pd.projectile) AS "Projectile",
    MAX(utd.unit_type) AS "Unit Type",
    MAX(rpd.rounds_package) AS "Rounds/Package",
    MAX(asd.attribute_set_name) AS "Attribute Set",
    cd.categories AS "Categories",
    MAX(CASE WHEN va.attribute_code = 'gun_type' THEN va.value END) AS "Gun Type",
    MAX(ddc.ddcaliber) AS "DD Caliber",
    MAX(ddact.ddaction) AS "DD Gun Action",
    MAX(ddcond.ddcondition) AS "DD Condition",
    MAX(ddgp.ddgun_parts) AS "DD Gun Parts",
    MAX(capacity.capacity) AS "Capacity",
    MAX(material.material) AS "Material",
    MAX(pc.primary_category) AS "Primary Category",
    MAX(dc.ddcolor) AS "DD Color",
    MAX(oc.optic_coating) AS "Optic Coating",
    MAX(dwp.ddweapons_platform) AS "DD Weapons Platform",
    MAX(CASE WHEN va.attribute_code = 'thread_pattern' THEN va.value END) AS "Thread Pattern", -- Added column for thread_pattern
    MAX(CASE WHEN va.attribute_code = 'thread_type' THEN va.value END) AS "Thread Type", -- Added column for thread_type
    MAX(CASE WHEN va.attribute_code = 'model' THEN va.value END) AS "Model",
    Coalesce(MAX(fbc.CONVERT),1) AS CONVERT,
    MAX(fbc.avgcost) AS AVGCOST,
    MAX(fbc.LASTVENDORCOST) AS LASTVENDORCOST -- Added column for model
FROM 
    ad_magento.catalog_product_entity e
LEFT JOIN varchar_attributes va ON e.entity_id = va.entity_id
LEFT JOIN int_attributes ia ON e.entity_id = ia.entity_id
LEFT JOIN decimal_attributes da ON e.entity_id = da.entity_id
LEFT JOIN text_attributes ta ON e.entity_id = ta.entity_id
LEFT JOIN category_data cd ON e.entity_id = cd.product_id
LEFT JOIN vendor_data vd ON e.entity_id = vd.entity_id
LEFT JOIN parent_sku_data psd ON e.entity_id = psd.product_id
LEFT JOIN discontinued_data dd ON e.entity_id = dd.entity_id
LEFT JOIN manufacturer_data md ON e.entity_id = md.entity_id
LEFT JOIN projectile_data pd ON e.entity_id = pd.entity_id
LEFT JOIN unit_type_data utd ON e.entity_id = utd.entity_id
LEFT JOIN ddcaliber_data ddc ON e.entity_id = ddc.entity_id
LEFT JOIN ddaction_data ddact ON e.entity_id = ddact.entity_id
LEFT JOIN ddcondition_data ddcond ON e.entity_id = ddcond.entity_id
LEFT JOIN ddgun_parts_data ddgp ON e.entity_id = ddgp.entity_id
LEFT JOIN rounds_package_data rpd ON e.entity_id = rpd.entity_id
LEFT JOIN capacity_data capacity ON e.entity_id = capacity.entity_id
LEFT JOIN material_data material ON e.entity_id = material.entity_id
LEFT JOIN attribute_set_data asd ON e.entity_id = asd.entity_id
LEFT JOIN primary_category_data pc ON e.entity_id = pc.entity_id
LEFT JOIN ddcolor_data dc ON e.entity_id = dc.entity_id
LEFT JOIN optic_coating_data oc ON e.entity_id = oc.entity_id
LEFT JOIN ddweapons_platform_data dwp ON e.entity_id = dwp.entity_id
LEFT JOIN FISHBOWL_CONVERSION fbc ON e.sku = fbc.num

GROUP BY e.entity_id, e.sku, cd.categories, vd.vendor, dd.discontinued, psd.parent_sku;

create or replace view AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME(
	CREATED_AT,
	TIMEDATE,
	TRICKAT,
	PRODUCT_ID,
	ORDER_ID,
	ROW_TOTAL,
	BASE_COST,
	TESTSKU,
	PRODUCT_TYPE,
	DISTINCT_ORDER_ID_COUNT,
	DISTINCT_ORDER_ID_BY_TESTSKU
) as

/*------------------------------------------------------------------
  1) Interaction – fonte única
------------------------------------------------------------------*/
WITH Interaction AS (
    SELECT
        TO_TIMESTAMP_NTZ(CONVERT_TIMEZONE('America/New_York', z.created_at)) AS CREATED_AT,
        TO_TIMESTAMP_NTZ(CONVERT_TIMEZONE('America/New_York', z.created_at)) AS TIMEDATE,
        z.created_at           AS TRICKAT,
        z.product_id           AS PRODUCT_ID,
        z.order_id             AS ORDER_ID,
        z.row_total 
            - COALESCE(z.amount_refunded, 0) 
            - COALESCE(z.discount_amount, 0) 
            + COALESCE(z.discount_refunded, 0) AS ROW_TOTAL,
            z.base_cost,
        z.sku                 AS TESTSKU,
        z.product_type        AS PRODUCT_TYPE,
        z.item_id             AS ID,
        z.parent_item_id
    FROM AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z
    JOIN AD_AIRBYTE.AD_MAGENTO.SALES_ORDER t
      ON z.order_id = t.entity_id
    WHERE 
        t.created_at >= DATEADD(day, -4, CURRENT_DATE())  -- histórico curto
),

/*------------------------------------------------------------------
  2) ToTransfer – somente itens ‘configurable’
------------------------------------------------------------------*/
ToTransfer AS (
    SELECT
        ID,
        PRODUCT_ID,
        base_cost,
        ROW_TOTAL AS CONFIG_ROW_TOTAL
    FROM Interaction
    WHERE PRODUCT_TYPE = 'configurable'
),

/*------------------------------------------------------------------
  3) Last – aplica ROW_TOTAL do pai “configurable”
------------------------------------------------------------------*/
Last AS (
    SELECT
        i.CREATED_AT,
        i.TIMEDATE,
        i.TRICKAT,
        i.PRODUCT_ID,
        i.ORDER_ID,
        CASE 
            WHEN t.ID IS NOT NULL THEN t.CONFIG_ROW_TOTAL 
            ELSE i.ROW_TOTAL 
        END AS ROW_TOTAL,
        CASE 
            WHEN t.ID IS NOT NULL THEN t.base_cost
            ELSE i.base_cost 
        END AS base_cost,
        i.TESTSKU,
        i.PRODUCT_TYPE
    FROM Interaction i
    LEFT JOIN ToTransfer t
      ON i.parent_item_id = t.ID
    WHERE i.PRODUCT_TYPE <> 'configurable'
),

/*------------------------------------------------------------------
  4) Filtro para hoje (fuso America/New_York)
------------------------------------------------------------------*/
LastToday AS (
    SELECT *
    FROM Last
    WHERE CAST(CREATED_AT AS DATE) = CAST(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_TIMESTAMP()) AS DATE)
),

/*------------------------------------------------------------------
  5) Contagem total de pedidos únicos do dia
------------------------------------------------------------------*/
DistinctCount AS (
    SELECT COUNT(DISTINCT ORDER_ID) AS DISTINCT_ORDER_ID_COUNT
    FROM LastToday
),

/*------------------------------------------------------------------
  6) Contagem de pedidos distintos por SKU
------------------------------------------------------------------*/
SkuOrderCounts AS (
    SELECT
        TESTSKU,
        COUNT(DISTINCT ORDER_ID) AS DISTINCT_ORDER_ID_BY_TESTSKU
    FROM LastToday
    GROUP BY TESTSKU
)

/*------------------------------------------------------------------
  7) Saída final
------------------------------------------------------------------*/


------------------------------------------------------------------*/
SELECT
    l.CREATED_AT,
    l.TIMEDATE,
    l.TRICKAT,
    l.PRODUCT_ID,
    l.ORDER_ID,
    l.ROW_TOTAL,
    l.BASE_COST,
    l.TESTSKU,
    l.PRODUCT_TYPE,
    d.DISTINCT_ORDER_ID_COUNT,
    s.DISTINCT_ORDER_ID_BY_TESTSKU
FROM LastToday l
CROSS JOIN DistinctCount d
LEFT JOIN SkuOrderCounts s ON l.TESTSKU = s.TESTSKU
ORDER BY l.CREATED_AT DESC;

create or replace view AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS(
	CREATED_AT,
	TIMEDATE,
	ID,
	INCREMENT_ID,
	"Início da Hora - Copiar",
	PRODUCT_ID,
	ORDER_ID,
	TRICKAT,
	PRODUCT_OPTIONS,
	PRODUCT_TYPE,
	PARENT_ITEM_ID,
	TESTSKU,
	CONVERSION,
	"Início da Hora",
	CUSTOMER_EMAIL,
	POSTCODE,
	COUNTRY,
	REGION,
	CITY,
	STREET,
	TELEPHONE,
	CUSTOMER_NAME,
	STORE_ID,
	STATUS,
	ROW_TOTAL,
	COST,
	QTY_ORDERED,
	FREIGHT_REVENUE,
	FREIGHT_COST,
	TESTC,
	TESTR,
	TESTFR,
	TESTFC,
	VENDOR,
	CUSTOMER_ID,
	RANK_ID,
	PART_QTY_SOLD
) as 
//Start Code Conversions Fishbowl Magento

WITH Magento_Identities AS (
    SELECT
        CASE
            WHEN f.value:value IS NOT NULL AND f.value:value != '' THEN f.value:value::STRING
            ELSE NULL
        END AS magento_order_item_identity,
        a.id AS code
    FROM
        AD_AIRBYTE.AD_FISHBOWL.SO a,
        LATERAL FLATTEN(input => PARSE_JSON(a.CUSTOMFIELDS)) f
    WHERE
        f.value:name = 'Magento Order Identity 1'
        -- FILTER: Only get SO records from last 4 days
        AND a.dateissued >= DATEADD(day, -4, CURRENT_DATE())
),

Conversion AS (
    SELECT
        f.recordid  AS IDFB,
        f.channelid AS MGNTID
    FROM AD_AIRBYTE.AD_FISHBOWL.PLUGININFO f
    WHERE f.tablename = 'SOItem'
),

Conversion1 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AD_FISHBOWL.PLUGININFO f
    WHERE
        f.TABLENAME = 'Product'
),

Conversion2 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AD_FISHBOWL.PLUGININFO f
    WHERE
        f.TABLENAME = 'SO'
),
//END Code Conversions Fishbowl Magento

//Start - Real Cost and Estimated Cost Segregation By Magento Correspondency (Magento Sales Order Item ID 1 or more codes duplicated)

COST_TEST AS (
    SELECT 
        z.totalcost AS COST,
        m.magento_order_item_identity AS MAGENTO_ORDER,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,

        /* Regra:
           - pega do customfields (25.value) se existir e não for vazio
           - senão, fallback para o que já vinha (child.MGNTID)
        */
        COALESCE(
            NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
            child.MGNTID
        ) AS SALES_ORDER_ITEM_MAGENTO,

        z.id AS ID_SOItem,
        z.soid AS ORDER_FISHBOWL_ID
    FROM AD_AIRBYTE.AD_FISHBOWL.SOITEM z
    LEFT JOIN CONVERSION child
        ON z.id = child.idfb
    LEFT JOIN CONVERSION1 t
        ON z.productid = t.PRODUTOFISH
    LEFT JOIN Magento_Identities m
        ON z.SOID = m.code
    -- FILTER: Only get SOITEM records from last 4 days
    WHERE z.datescheduledfulfillment >= DATEADD(day, -4, CURRENT_DATE())
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
    FROM AD_AIRBYTE.AD_FISHBOWL.UOMCONVERSION z
    WHERE z.touomid = 1
),

PRODUCTCODE AS (
    SELECT  
        ty.id AS ID_PRODUTO,
        z.Multiply AS CONVERSION,
        COALESCE(y.avgcost * z.multiply, y.avgcost) AS AVERAGECOST,
        y.avgcost AS COSTNOCONVERSION
    FROM 
        AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty
    LEFT JOIN
        AD_AIRBYTE.AD_FISHBOWL.PARTCOST y ON ty.partid = y.partid
    LEFT JOIN 
        TOUOMTEST z ON UOMID= z.FROMUOMID
),
//End of Expected Cost
ObjectKIT AS (
select * FROM AD_AIRBYTE.AD_FISHBOWL.OBJECTTOOBJECT WHERE typeid = 30),

//End of Expected Cost

//Start of KITID Conversion
Aggregation5 AS (
    SELECT 
        
        COALESCE(NULLIF(Sum(z.totalcost),0),  SUM(z.QTYORDERED * y.averagecost))
         as COST,
         obk.recordid2 AS KITID,
        SUM(y.averagecost) AS COSTPROCESSING,
        MAX(QTYORDERED) AS MAXQTYTEST
    FROM 
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
    LEFT JOIN
        PRODUCTCODE y ON z.productid = y.id_produto
    LEFT JOIN 
        objectkit obk ON z.id = obk.recordid1 
    WHERE 
        z.typeid = '10' AND z.description NOT LIKE '%POLLYAMOBAG%'
        -- FILTER: Only get SOITEM records from last 4 days
        AND z.datescheduledfulfillment >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY
         obk.recordid2
),

Cost_Fishbowl AS (
    SELECT 
        CASE 
            WHEN z.totalcost = 0 THEN zy.cost
            ELSE z.totalcost 
        END AS COST,

        m.magento_order_item_identity AS MAGENTO_ORDER,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,

        /* REGRA NOVA p/ ID_MAGENTO:
           - tenta pegar do customfields (path 25.value)
           - se vier vazio, cai no child.MGNTID (que já é a regra antiga / fallback)
        */
        COALESCE(
            NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
            child.MGNTID
        ) AS ID_MAGENTO,

        z.customfields,
        z.id AS ID_SOItem,
        z.productnum,
        z.soid AS ORDER_FISHBOWL_ID,
        f.Count_of_ID_MAGENTO AS Count_of_ID_MAGENTO,
        z.productid AS ID_PRODUTO_FISHBOWL,
        ty.kitflag AS BUNDLE,
        COALESCE(COALESCE(zy.COSTPROCESSING, tz.AverageCOST), tz.AverageCOST) AS AverageWeightedCost,
        z.datescheduledfulfillment AS DATESCHEDULEFULFILLMENT,
        z.qtyfulfilled AS qty

    FROM AD_AIRBYTE.AD_FISHBOWL.SOITEM z

    LEFT JOIN CONVERSION child
        ON z.id = child.idfb

    LEFT JOIN PRODUCTCODE tz
        ON z.productid = tz.ID_PRODUTO

    LEFT JOIN CONVERSION1 t
        ON z.productid = t.PRODUTOFISH

    LEFT JOIN Magento_Identities m
        ON z.SOID = m.code

    LEFT JOIN AGGREGATION f
        ON COALESCE(
               NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
               child.MGNTID
           ) = f.ID

    LEFT JOIN AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty
        ON z.productid = ty.id

    LEFT JOIN AGGREGATION5 zy
        ON z.id = zy.kitid

    -- FILTER: Only get SOITEM records from last 4 days
    WHERE z.datescheduledfulfillment >= DATEADD(day, -4, CURRENT_DATE())  
),

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
        Last_Day_Cost ld 
      ON TO_VARCHAR(z.ID_PRODUTO_FISHBOWL) = TO_VARCHAR(ld.PRODUCT_ID) 
     AND z.DATESCHEDULEFULFILLMENT = ld.LAST_SCHEDULED_DATE
    WHERE 
        z.Cost IS NOT NULL AND z.Cost > 0
    GROUP BY 
        z.ID_PRODUTO_FISHBOWL
),
Cost_Fishbowl1 AS (
    SELECT 
        COALESCE(NULLIF(z.totalcost, 0), NULLIF(zy.cost, 0)) AS cost,
        z.totalcost AS TOTALCOST,
        z.CUSTOMFIELDS,
        z.CUSTOMERPARTNUM,
        zy.cost AS COSTBUNDLE,
        m.magento_order_item_identity AS MAGENTO_ORDER,
        cty.cost AS COSTFILTERED,
        t.PRODUTO_MAGENTO AS ID_PRODUTO_MAGENTO,

        COALESCE(
            NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
            child.MGNTID
        ) AS ID_MAGENTO,

        z.id AS ID_SOItem,
        z.soid AS ORDER_FISHBOWL_ID,
        f.Count_of_ID_MAGENTO AS Count_of_ID_MAGENTO,
        z.productid AS ID_PRODUTO_FISHBOWL,
        ty.kitflag AS BUNDLE,
        COALESCE(COALESCE(zy.COSTPROCESSING, tz.AverageCOST), tz.AverageCOST) AS AverageWeightedCost,
        z.datescheduledfulfillment AS DATESCHEDULEFULFILLMENT,
        z.qtyfulfilled AS qty
    FROM AD_AIRBYTE.AD_FISHBOWL.SOITEM z
    LEFT JOIN CONVERSION child
        ON z.id = child.idfb
    LEFT JOIN PRODUCTCODE tz
        ON z.productid = tz.ID_PRODUTO
    LEFT JOIN CONVERSION1 t
        ON z.productid = t.PRODUTOFISH
    LEFT JOIN Magento_Identities m
        ON z.SOID = m.code
    LEFT JOIN AGGREGATION f
        ON COALESCE(
               NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
               child.MGNTID
           ) = f.ID
    LEFT JOIN AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty
        ON z.productid = ty.id
    LEFT JOIN AGGREGATION5 zy
        ON z.id = zy.kitid
    LEFT JOIN Filtered_COST cty
        ON TO_VARCHAR(z.productid) = TO_VARCHAR(cty.PRODUCT_ID)

    WHERE z.datescheduledfulfillment >= DATEADD(day, -4, CURRENT_DATE()) 
),

//START - Creating the Different Keys Fishbowl Magento Integration
COST1 AS (
    SELECT *
    FROM
        Cost_Fishbowl1 y
    LEFT JOIN
        Aggregation f ON y.ID_MAGENTO = f.ID 
    WHERE f.Count_of_ID_MAGENTO = 1
),

COST2 AS (
    SELECT
        AVG(y.cost) AS COST,
        y.ID_MAGENTO,
        AVG(y.AverageWeightedCost) AS AverageWeightedCost,
        y.ID_PRODUTO_MAGENTO
    FROM
        Cost_Fishbowl1 y
    LEFT JOIN
        Aggregation f ON y.ID_MAGENTO = f.ID 
    WHERE f.Count_of_ID_MAGENTO > 1
    GROUP BY y.id_magento, id_Produto_magento
),

COST3 AS (
    SELECT 
        AVG(COST) AS COST,
        AVG(AverageWeightedCost) AS AverageWeightedCost,
        ID_MAGENTO
    FROM 
        COST2
    LEFT JOIN
        AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z ON ID_MAGENTO = z.item_id
    WHERE z.ROW_TOTAL <> 0
        AND z.created_at >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY 
        ID_MAGENTO
),

STATUSProcessing AS (
    SELECT
        z.order_id AS order_id,
        SUM(COALESCE(f.COST, y.COST)) AS COST,
        SUM(COALESCE(f.AverageWeightedCost, y.AverageWeightedCost)) AS COST_AVERAGE_ORDER
    FROM
        AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z
    LEFT JOIN
        COST1 f ON z.item_id = f.ID_MAGENTO
    LEFT JOIN
        COST2 y ON concat(z.item_id, '@', z.product_id) = concat(y.ID_MAGENTO, '@', y.ID_PRODUTO_MAGENTO)
    WHERE z.created_at >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY 
        z.order_id
),

//START - First Interaction - Fishbowl Magento
Interaction as (
SELECT 
    to_timestamp_ntz(CONVERT_TIMEZONE('America/New_York', z.created_at)) AS CREATED_AT,
    z.product_id AS product_id,
    z.order_id AS order_id,
    z.qty_ordered AS qty_ordered,
    z.discount_invoiced AS discount_invoiced,
    concat(z.product_id, '@', z.order_id) AS CHAVE,

    /* mantém seu COST antigo aqui (debug / outros usos),
       mas NÃO será mais usado como COST final */
    COALESCE(
        f.COST, y.COST, tz.cost,
        f.AverageWeightedCost*z.qty_ordered,
        y.AverageWeightedCost*z.qty_ordered,
        tz.averageweightedcost*z.qty_ordered
    ) AS COST,

    COALESCE(f.AverageWeightedCost, y.AverageWeightedCost, tz.averageweightedcost) AS AverageWeightedCost,
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
    z.base_cost,
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
    AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z
LEFT JOIN 
    AD_AIRBYTE.AD_MAGENTO.SALES_ORDER t ON z.order_id = t.entity_ID
LEFT JOIN 
    AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ADDRESS child ON t.BILLING_ADDRESS_ID = child.entity_id
LEFT JOIN 
    COST1 f ON z.item_id = f.ID_MAGENTO
LEFT JOIN 
    COST2 y ON concat(z.item_id, '@', z.product_id) = concat(y.ID_MAGENTO, '@', y.ID_PRODUTO_MAGENTO)
LEFT JOIN 
    COST3 tz ON z.item_id = tz.ID_MAGENTO
LEFT JOIN 
    STATUSPROCESSING p ON z.order_id = p.order_id
WHERE t.created_at >= DATEADD(day, -4, CURRENT_DATE()) 
),

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
      ON to_VARCHAR(z.product_ID) = TO_VARCHAR(ldc1.PRODUCT_ID)
     AND z.created_at = ldc1.LAST_SCHEDULED_DATE
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

//START - Freight Allocation in product by Weight Inside Order
NEWSHIP AS (
    SELECT 
        SUM(Net_amount) AS NET_AMOUNT,
        tracking_number as TRACKING_NUMBER
    FROM PC_FIVETRAN_DB.UPS_INVOICE_HISTORY.UPS_INVOICE
    GROUP BY TRACKING_NUMBER
),

SHIPTRANSFORMATION AS (
    SELECT 
        z.SOID AS SOID,
        COALESCE(SUM(nw.net_amount), SUM(t.freightamount)) as FREIGHTAMOUNT,
        SUM(t.freightweight) as FREIGHTWEIGHT,
        AVG(z.carrierserviceid) as CARRIERSERVICEID,
        SUM(nw.net_amount) AS AmountUPS,
        COUNT(t.trackingnum) AS PACKAGENUMB
    FROM AD_AIRBYTE.AD_FISHBOWL.SHIP z
    LEFT JOIN AD_AIRBYTE.AD_FISHBOWL.SHIPCARTON t ON z.id = t.SHIPID
    LEFT JOIN NEWSHIP nw ON t.trackingnum = nw.tracking_number
    GROUP BY z.soid
),

FreightInfo AS (
    SELECT 
        ty.PRODUTO_MAGENTO as Order_magento,
        AVG(t.freightamount) as freightamount,
        AVG(t.freightweight) as freightweight,
        AVG(t.carrierserviceid) as CARRIERSERVICEID
    FROM AD_AIRBYTE.AD_FISHBOWL.SO z
    LEFT JOIN SHIPTRANSFORMATION t on TO_VARCHAR(z.id) = TO_VARCHAR(t.SOID)
    LEFT JOIN Conversion2 ty on z.id = ty.PRODUTOFISH
    WHERE z.dateissued >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY ty.Produto_MAGENTO
),

ORDERNOZERO AS (
    SELECT 
         z.weight AS WEIGHT,
         z.order_id AS ORDER_ID,
         z.sku,
         z.product_id,
         z.qty_ordered AS qty_ordered,
         z.qty_ordered  AS TEST,
         z.row_total
           - COALESCE(z.amount_refunded, 0)
           - COALESCE(z.discount_amount, 0)
           + COALESCE(z.discount_refunded, 0)
         AS row_total
    FROM AD_AIRBYTE.AD_MAGENTO.sales_order_item z
    LEFT JOIN AD_AIRBYTE.AD_MAGENTO.catalog_product_entity ct 
           ON z.product_id = ct.entity_id
    WHERE 
        div0(
            (z.row_total 
             - COALESCE(z.amount_refunded,0) 
             - COALESCE(z.discount_amount,0) 
             + COALESCE(z.discount_refunded,0)) * z.qty_ordered,
            (z.row_total 
             - COALESCE(z.amount_refunded,0) 
             - COALESCE(z.discount_amount,0) 
             + COALESCE(z.discount_refunded,0))
        ) <> 0
      AND ct.sku NOT ILIKE '%parceldefender%'
      AND z.created_at >= DATEADD(day, -4, CURRENT_DATE())
),

WeightOrder AS (
    SELECT 
        SUM(z.weight) as WEIGHT,
        z.order_id as ORDER_ID,
        COUNT(z.product_Id) AS Products
    FROM ORDERNOZERO z
    GROUP BY z.order_id
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
        SUM(
            COALESCE(ty.BASE_SHIPPING_AMOUNT,0)
            - COALESCE(ty.BASE_SHIPPING_TAX_AMOUNT,0)
            - COALESCE(ty.BASE_SHIPPING_REFUNDED,0)
            + COALESCE(ty.BASE_SHIPPING_TAX_REFUNDED,0)
        ) AS NETSALES,
        ty.entity_id AS ORDER_ID,
        SUM(zy.freightamount) as Freightamount
    FROM AD_AIRBYTE.AD_MAGENTO.SALES_ORDER ty 
    LEFT JOIN FreightInfo zy ON TO_VARCHAR(ty.entity_id) = TO_VARCHAR(zy.order_magento)
    WHERE ty.created_at >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY ty.entity_id
),

Product_Sales AS (
    SELECT
        s.ITEM_ID,
        SUM(s.qty_ordered * COALESCE(uom.multiply, 1)) AS Part_Qty_Sold,
        AVG(UOM.multiply) AS CONVERSION,
        cpe.sku AS SKU
    FROM AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM s
    JOIN AD_AIRBYTE.AD_MAGENTO.SALES_ORDER o ON s.order_id = o.entity_id
    JOIN AD_AIRBYTE.AD_MAGENTO.CATALOG_PRODUCT_ENTITY cpe ON s.product_id = cpe.entity_id
    JOIN AD_AIRBYTE.AD_FISHBOWL.PRODUCT pr ON cpe.sku = pr.num
    JOIN AD_AIRBYTE.AD_FISHBOWL.PART p ON pr.partid = p.id
    LEFT JOIN AD_AIRBYTE.AD_FISHBOWL.UOMCONVERSION uom 
      ON pr.uomid = uom.fromuomid AND uom.touomid = 1
    WHERE s.product_type <> 'bundle'
        AND s.price > 0
        AND s.created_at >= DATEADD(day, -4, CURRENT_DATE())
    GROUP BY s.ITEM_ID, cpe.sku
    ORDER BY SUM(s.row_invoiced) DESC
),

SKUBASE AS (
   SELECT 
    to_date(z.created_at) AS CREATED_AT,
    z.created_at AS TIMEDATE,
    DATE_TRUNC('HOUR', z.created_at) as tIniciodaHoraCopiar,
    z.product_id AS PRODUCT_ID,
    z.order_id AS ORDER_ID,
    z.qty_ordered  AS QTY_ORDERED,
    z.qty_ordered AS ORDERED,
    z.discount_invoiced AS DISCOUNT_INVOICED,
    concat(z.product_id, '@', z.order_id) AS CHAVE,

    CASE WHEN z.qty_ordered > 0 THEN z.cost ELSE NULL END AS COST,

    z.AverageWeightedCost AS AVERAGE_WEIGHTED_COST,
    z.tax_amount AS TAX_AMOUNT,
    z.row_total AS ROW_TOTAL,
    z.increment_ID AS INCREMENT_ID,
    z.BILLING_ADDRESS_ID AS BILLING_ADDRESS_ID,
    z.customer_email AS CUSTOMER_EMAIL,
    z.postcode AS POSTCODE,
    z.country AS COUNTRY,
    z.base_cost,
    z.region AS REGION,
    z.city AS CITY,
    z.STREET as STREET,
    z.telephone AS TELEPHONE,
    z.customer_name AS CUSTOMER_NAME,
    z.ID AS ID,
    UPPER(z.status) AS STATUS,
    z.COST AS ORDER_COST,
    z.FISHBOWL_REGISTEREDCOST AS FISHBOWL_REGISTERED_COST,
    z.store_id AS STORE_ID,
    z.store_name AS STORE_NAME,
    z.weight AS WEIGHT,
    div0(z.weight, ctm.weight) AS Percentage,
    ctm.weight AS WeightORDER,

    CASE 
      WHEN ctm.weight IS NULL AND z.testsku NOT ILIKE '%parceldefender%' 
        THEN div0null(
             div0(z.qty_ordered * z.row_total, z.row_total) * ty.netsales,
             ctm.products * div0(z.qty_ordered * z.row_total, z.row_total)
        )
      ELSE div0null(
             z.weight * div0(z.qty_ordered * z.row_total, z.row_total) * ty.netsales,
             ctm.weight * div0(z.qty_ordered * z.row_total, z.row_total)
        )
    END AS FREIGHT_REVENUE,

    CASE 
      WHEN ctm.weight IS NULL AND z.testsku NOT ILIKE '%parceldefender%' 
        THEN div0null(
             div0(z.qty_ordered * z.row_total, z.row_total),
             ctm.products * div0(z.qty_ordered * z.row_total, z.row_total)
        ) * Freightamount
      ELSE div0null(
             z.weight * div0(z.qty_ordered * z.row_total, z.row_total),
             ctm.weight * div0(z.qty_ordered * z.row_total, z.row_total)
        ) * Freightamount
    END AS FREIGHT_COST,

    z.cost1,
    z.cost2,
    z.cost3,
    z.average1,
    z.average2,
    z.average3,
    ctw.Part_Qty_Sold,
    COALESCE(ctw.Conversion, 1) AS Conversion,
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

/* >>> ALTERADO: adiciona base_cost do configurable para transferir junto <<< */
ToTRANSFER AS ( 
SELECT 
    id AS ID,
    row_total,
    cost,
    freight_revenue,
    freight_cost,
    qty_ordered,
    part_qty_sold
FROM SKUBASE
WHERE product_type = 'configurable'
),

/* >>> ALTERADO: base_cost/qty e COST final com regra do configurable <<< */
LAST AS (
SELECT 
    z.CREATED_AT,
    z.TIMEDATE,
    ty.cost AS COSTTOTRANSFER,
    z.id AS ID,
    z.increment_id,
    z.parent_item_id,
    z.product_options,
    z.product_type,
    z.tIniciodaHoraCopiar AS tIniciodaHoraCopiar,
    z.PRODUCT_ID,
    z.ORDER_ID,
    z.created_at AS TrickAT,
    
    z.cost as CUSTONORMAL,

    z.TESTSKU as TESTSKU,
    z.conversion,
    z.tIniciodaHora AS tIniciodaHora,
    z.customer_email AS CUSTOMER_EMAIL,
    z.postcode AS POSTCODE,
    z.country AS COUNTRY,
    z.region AS REGION,
    z.city AS CITY,

    /* base_cost: se tiver parent configurable, usa o base_cost do parent */

    z.street AS STREET,
    z.telephone AS TELEPHONE,
    z.customer_name AS CUSTOMER_NAME,
    z.store_id AS STORE_ID,
    z.status AS STATUS,
    z.vendor,
    z.customer_id,

    /* ROW_TOTAL: mantém */
    CASE WHEN ty.ID IS NOT NULL THEN ty.row_total ELSE z.row_total END AS ROW_TOTAL,

    /* QTY_ORDERED: se tiver parent configurable, usa qty do parent */
    CASE WHEN ty.ID IS NOT NULL THEN ty.qty_ordered ELSE z.qty_ordered END AS QTY_ORDERED,

    /* COST FINAL: base_cost (Magento) * qty_ordered (com regra do configurable) */
    CASE WHEN ty.ID IS NOT NULL AND ty.cost IS NOT NULL THEN ty.cost ELSE z.cost END AS COST,

    /* resto mantém */
    CASE WHEN ty.ID IS NOT NULL THEN ty.Part_Qty_Sold ELSE z.Part_Qty_Sold END AS Part_Qty_Sold,  
    CASE WHEN ty.ID IS NOT NULL THEN ty.Freight_revenue ELSE z.freight_revenue END AS freight_revenue,
    CASE WHEN ty.ID IS NOT NULL THEN ty.Freight_cost ELSE z.freight_cost END AS freight_cost,

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
      ON to_VARCHAR(z.product_ID) = TO_VARCHAR(ldc1.PRODUCT_ID)
     AND z.TrickAT = ldc1.LAST_SCHEDULED_DATE
    WHERE 
        z.COST > 0 AND z.qty_ordered > 0
),
FILTERED_COST3 AS (
    SELECT 
        z.product_ID,
        DIV0(SUM(z.COST), SUM(z.qty)) AS COST,
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
    z.store_id AS STORE_ID,
    z.status AS STATUS,
    z.ROW_TOTAL,

    /* COST FINAL vindo do Magento base_cost * qty (com regra do configurable) */
    coalesce(z.COST,zyt.cost*z.qty_ordered) AS COST,

    z.QTY_ORDERED,
    z.freight_revenue,
    z.freight_cost,
    z.TESTC,
    z.TestR,
    z.TestFR,
    z.TESTFC,
    z.vendor,
    z.customer_id,
    upt.rank_id,
    COALESCE(z.Part_Qty_Sold, z.qty_ordered) AS Part_Qty_Sold
FROM
    LAST z
LEFT JOIN Filtered_COST3 zyt 
  ON TO_VARCHAR(z.product_id) = TO_VARCHAR(zyt.PRODUCT_ID)
LEFT JOIN AD_AIRBYTE.AD_REALTIME.d_customerupdated upt 
  ON LOWER(COALESCE(NULLIF(z.CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) = upt.customer_email
WHERE
    z.product_type <> 'configurable'
ORDER BY
    z.CREATED_AT DESC;



create or replace view AD_AIRBYTE.AD_MAGENTO.F_SALES_REALTIME(
	CREATED_AT,
	TIMEDATE,
	ID,
	INCREMENT_ID,
	"Início da Hora - Copiar",
	PRODUCT_ID,
	ORDER_ID,
	TRICKAT,
	PRODUCT_OPTIONS,
	PRODUCT_TYPE,
	PARENT_ITEM_ID,
	TESTSKU,
	CONVERSION,
	"Início da Hora",
	CUSTOMER_EMAIL,
	POSTCODE,
	COUNTRY,
	REGION,
	CITY,
	STREET,
	TELEPHONE,
	CUSTOMER_NAME,
	STORE_ID,
	STATUS,
	ROW_TOTAL,
	COST,
	QTY_ORDERED,
	FREIGHT_REVENUE,
	FREIGHT_COST,
	TESTC,
	TESTR,
	TESTFR,
	TESTFC,
	VENDOR,
	CUSTOMER_ID,
	RANK_ID,
	PART_QTY_SOLD
) as 
//Start Code Conversions Fishbowl Magento

WITH Magento_Identities AS (
    SELECT
        CASE
            WHEN f.value:value IS NOT NULL AND f.value:value != '' THEN f.value:value::STRING
            ELSE NULL
        END AS magento_order_item_identity,
        a.id AS code
    FROM
        AD_AIRBYTE.AD_FISHBOWL.SO a,
        LATERAL FLATTEN(input => PARSE_JSON(a.CUSTOMFIELDS)) f
    WHERE
        f.value:name = 'Magento Order Identity 1'
),

-- ============================================================================
-- FIX: Updated Conversion CTE to check BOTH customfields JSON AND plugininfo
-- This ensures backward compatibility with old orders (plugininfo) while
-- supporting new orders (customfields JSON at $."25"."value")
-- ============================================================================
Conversion AS (
    SELECT 
        z.id AS IDFB,
        COALESCE(
            NULLIF(PARSE_JSON(z.customfields):"25":"value"::STRING, ''),
            p.channelid
        ) AS MGNTID
    FROM
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
    LEFT JOIN
        AD_AIRBYTE.AD_FISHBOWL.PLUGININFO p ON p.recordid = z.id AND p.tablename = 'SOItem'
),
-- ============================================================================

Conversion1 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AD_FISHBOWL.PLUGININFO f
    WHERE
        f.TABLENAME = 'Product'
),

Conversion2 AS (
    SELECT 
        f.recordId as PRODUTOFISH,
        f.CHANNELID as PRODUTO_MAGENTO
    FROM
        AD_AIRBYTE.AD_FISHBOWL.PLUGININFO f
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
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
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
    FROM AD_AIRBYTE.AD_FISHBOWL.UOMCONVERSION z
    WHERE z.touomid = 1
),

PRODUCTCODE AS (
    SELECT  
        ty.id AS ID_PRODUTO,
        z.Multiply AS CONVERSION,
        COALESCE(y.avgcost * z.multiply, y.avgcost) AS AVERAGECOST,
        y.avgcost AS COSTNOCONVERSION
    FROM 
        AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty
    LEFT JOIN
        AD_AIRBYTE.AD_FISHBOWL.PARTCOST y ON ty.partid = y.partid
    LEFT JOIN 
        TOUOMTEST z ON UOMID= z.FROMUOMID
),
//End of Expected Cost
ObjectKIT AS (
select * FROM AD_AIRBYTE.AD_FISHBOWL.OBJECTTOOBJECT WHERE typeid = 30),

//End of Expected Cost

//Start of KITID Conversion
Aggregation5 AS (
    SELECT 
        
        COALESCE(NULLIF(Sum(z.totalcost),0),  SUM(z.QTYORDERED * y.averagecost))
         as COST,
         obk.recordid2 AS KITID,
        SUM(y.averagecost) AS COSTPROCESSING,
        MAX(QTYORDERED) AS MAXQTYTEST

        
    
    FROM 
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
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
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
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
        AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty ON z.productid = ty.id
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
        COALESCE(NULLIF(z.totalcost, 0), NULLIF(zy.cost, 0)) AS cost,
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
        AD_AIRBYTE.AD_FISHBOWL.SOITEM z
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
        AD_AIRBYTE.AD_FISHBOWL.PRODUCT ty ON z.productid = ty.id
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
        AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z ON ID_MAGENTO = z.item_id
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
        AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z
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
    AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM z
LEFT JOIN 
   AD_AIRBYTE.AD_MAGENTO.SALES_ORDER t ON z.order_id = t.entity_ID
LEFT JOIN 
   AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ADDRESS child ON t.BILLING_ADDRESS_ID = child.entity_id
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

    FROM AD_AIRBYTE.AD_FISHBOWL.SHIP z
    LEFT JOIN AD_AIRBYTE.AD_FISHBOWL.SHIPCARTON t ON z.id = t.SHIPID
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
AD_AIRBYTE.AD_FISHBOWL.SO z
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
    FROM AD_AIRBYTE.AD_MAGENTO.sales_order_item z
    LEFT JOIN AD_AIRBYTE.AD_MAGENTO.catalog_product_entity ct 
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
AD_AIRBYTE.AD_MAGENTO.SALES_ORDER ty 
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
       AD_AIRBYTE.AD_MAGENTO.SALES_ORDER_ITEM s
  

    JOIN
        AD_AIRBYTE.AD_MAGENTO.SALES_ORDER o ON s.order_id = o.entity_id
    JOIN
       AD_AIRBYTE.AD_MAGENTO.CATALOG_PRODUCT_ENTITY cpe ON s.product_id = cpe.entity_id
    JOIN
        AD_AIRBYTE.AD_FISHBOWL.PRODUCT pr ON cpe.sku = pr.num

    JOIN
        AD_AIRBYTE.AD_FISHBOWL.PART p ON pr.partid = p.id
    LEFT JOIN
        AD_AIRBYTE.AD_FISHBOWL.UOMCONVERSION uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1
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
AD_AIRBYTE.AD_REALTIME.d_customerupdated upt ON  LOWER(COALESCE(NULLIF(z.CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) = upt.customer_email


WHERE
z.product_type <> 'configurable'
ORDER BY
z.CREATED_AT DESC;


create or replace view AD_AIRBYTE.TEST_DTO.F_COHORT(
	COHORT_MONTH,
	MONTH_NUMBER,
	PURCHASERS,
	COHORT_SIZE
) as 
WITH sales_record AS (
SELECT * FROM F_SALES),




customer_cohort AS (
SELECT
  rank_id,
  MIN(DATE_TRUNC('MONTH', created_at)) AS cohort_month
FROM sales_record
GROUP BY rank_id),


CTE_Month AS (
SELECT
  o.rank_id,
  c.cohort_month,
  DATE_TRUNC('MONTH', o.created_at) AS order_month,
  DATEDIFF(MONTH, c.cohort_month, o.created_at) AS month_number
FROM sales_record o
JOIN customer_cohort c ON o.rank_id = c.rank_id)


SELECT
  cohort_month,
  month_number,
  COUNT(DISTINCT rank_id) AS purchasers,
  COUNT(DISTINCT CASE WHEN month_number = 0 THEN rank_id END) AS cohort_size
FROM (
  CTE_Month
)
GROUP BY cohort_month, month_number;

create or replace view AD_AIRBYTE.TEST_DTO.F_COHORTDETAILED(
	COHORT_MONTH,
	MONTH_NUMBER,
	"Manufacturer SKU",
	REGION,
	STORE_ID,
	PURCHASERS,
	COHORT_SIZE
) as 

WITH sales_record AS (
  SELECT * FROM f_sales
),


customer_cohort AS (
    SELECT
        rank_id,
        MIN(DATE_TRUNC('MONTH', created_at)) AS cohort_month
    FROM sales_record
    GROUP BY rank_id
),


CTE_Month AS (
    SELECT
        o.rank_id,
        c.cohort_month,
        DATE_TRUNC('MONTH', o.created_at) AS order_month,
        DATEDIFF(MONTH, c.cohort_month, o.created_at) AS month_number,
        p."Manufacturer SKU",
        o.REGION,
        o.STORE_ID
    FROM sales_record o
    JOIN customer_cohort c ON o.rank_id = c.rank_id
    JOIN d_product p ON o.product_id = p."Product ID"

)


SELECT
    cohort_month,
    month_number,
    "Manufacturer SKU",
    REGION,
    STORE_ID,

    COUNT(DISTINCT rank_id) AS purchasers,
    COUNT(DISTINCT CASE WHEN month_number = 0 THEN rank_id END) AS cohort_size
FROM CTE_Month
GROUP BY 
    cohort_month, 
    month_number, 
    "Manufacturer SKU",
    REGION, 
    STORE_ID;

create or replace view AD_AIRBYTE.TEST_DTO.D_PRODUCT(
	"Product ID",
	SKU,
	"Product Name",
	"General Purpose",
	"Product URL",
	"Product Image URL",
	"Vendor",
	"Discontinued",
	"Parent SKU",
	GROUPED_SKU,
	"Boxes/Case",
	"Caliber",
	"Manufacturer SKU",
	UPC,
	"Manufacturer",
	"Projectile",
	"Unit Type",
	"Rounds/Package",
	"Attribute Set",
	"Categories",
	"Gun Type",
	"DD Caliber",
	"DD Gun Action",
	"DD Condition",
	"DD Gun Parts",
	"Capacity",
	"Material",
	"Primary Category",
	"DD Color",
	"Optic Coating",
	"DD Weapons Platform",
	"Thread Pattern",
	"Thread Type",
	"Model",
	CONVERT,
	AVGCOST,
	LASTVENDORCOST
) as
WITH attribute_id_cte AS (
    SELECT attribute_id, attribute_code
    FROM eav_attribute
    WHERE attribute_code IN (
        'name', 'url_key', 'manufacturer_sku', 'upc', 'image', 'cost', 'price', 'status', 'visibility', 'weight', 
        'manufacturer', 'attribute_set_name', 'brand_type', 'grain_weight', 'unit_type', 'projectile', 'caliber', 
        'boxes_case', 'rounds_package', 'suggested_use', 'gun_type', 'ddcaliber', 'capacity', 
        'ddaction', 'ddcondition', 'material', 'ddgun_parts', 'primary_category', 'ddcolor', 'optic_coating', 'ddweapons_platform',
        'thread_pattern', 'thread_type', 'model' -- Added new attribute 'model'
    )
),
Test1 AS (
SELECT
* FROM
catalog_product_entity_int
),

varchar_attributes AS (
    SELECT cpv.entity_id, ac.attribute_code, cpv.value
    FROM catalog_product_entity_varchar cpv
    JOIN attribute_id_cte ac ON cpv.attribute_id = ac.attribute_id
    WHERE cpv.store_id = 0
),
text_attributes AS (
    SELECT cpt.entity_id, ac.attribute_code, cpt.value
    FROM catalog_product_entity_text cpt
    JOIN attribute_id_cte ac ON cpt.attribute_id = ac.attribute_id
    WHERE cpt.store_id = 0
),
int_attributes AS (
    SELECT cpi.entity_id, ac.attribute_code, cpi.value
    FROM Test1 cpi
    JOIN attribute_id_cte ac ON cpi.attribute_id = ac.attribute_id
    WHERE cpi.store_id = 0
),
decimal_attributes AS (
    SELECT cpd.entity_id, ac.attribute_code, cpd.value
    FROM catalog_product_entity_decimal cpd
    JOIN attribute_id_cte ac ON cpd.attribute_id = ac.attribute_id
    WHERE cpd.store_id = 0
),
category_data AS (
    SELECT ccp.product_id, LISTAGG(ccv.value, ' > ') WITHIN GROUP (ORDER BY ccv.value) AS categories
    FROM catalog_category_product ccp
    JOIN catalog_category_entity_varchar ccv ON ccp.category_id = ccv.entity_id
    JOIN attribute_id_cte ac ON ccv.attribute_id = ac.attribute_id AND ac.attribute_code = 'name'
    GROUP BY ccp.product_id
),

parent_sku_data AS (
    SELECT sl.product_id, parent.sku AS parent_sku
    FROM catalog_product_super_link sl
    JOIN catalog_product_entity parent ON sl.parent_id = parent.entity_id
),
discontinued_data AS (
    SELECT entity_id,
           CASE WHEN attribute_set_id = 50 THEN 'Yes' ELSE 'No' END AS discontinued
    FROM catalog_product_entity
),
manufacturer_data AS (
    SELECT cpi.entity_id, eov.value AS manufacturer
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 677 AND cpi.store_id = 0
),
projectile_data AS (
    SELECT cpi.entity_id, eov.value AS projectile
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 681 AND cpi.store_id = 0 
),
unit_type_data AS (
    SELECT cpi.entity_id, eov.value AS unit_type
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 649 AND cpi.store_id = 0 
),
ddcaliber_data AS (
    SELECT cpi.entity_id, eov.value AS ddcaliber
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 678 AND cpi.store_id = 0
),
ddaction_data AS (
    SELECT cpi.entity_id, eov.value AS ddaction
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 718 AND cpi.store_id = 0 
),
ddcondition_data AS (
    SELECT cpi.entity_id, eov.value AS ddcondition
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 676 AND cpi.store_id = 0 
),
ddgun_parts_data AS (
    SELECT cpi.entity_id, eov.value AS ddgun_parts
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 817 AND cpi.store_id = 0 
),
rounds_package_data AS (
    SELECT cpv.entity_id, cpv.value AS rounds_package
    FROM catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 152 AND cpv.store_id = 0
),
capacity_data AS (
    SELECT cpv.entity_id, cpv.value AS capacity
    FROM catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 165 AND cpv.store_id = 0
),
vendor_data AS (
    SELECT cpei.entity_id, ev.value AS vendor
    FROM catalog_product_entity_int cpei
    JOIN eav_attribute_option_value ev ON cpei.value = ev.option_id
    WHERE cpei.attribute_id = 145),
material_data AS (
    SELECT cpv.entity_id, cpv.value AS material
    FROM catalog_product_entity_varchar cpv
    WHERE cpv.attribute_id = 188 AND cpv.store_id = 0
),
attribute_set_data AS (
    SELECT cpe.entity_id, eas.attribute_set_name
    FROM catalog_product_entity cpe
    JOIN eav_attribute_set eas ON cpe.attribute_set_id = eas.attribute_set_id
),
primary_category_data AS (
    SELECT cpi.entity_id, eov.value AS primary_category
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 878 AND cpi.store_id = 0
),
ddcolor_data AS (
    SELECT cpi.entity_id, eov.value AS ddcolor
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 685 AND cpi.store_id = 0
),
optic_coating_data AS (
    SELECT cpt.entity_id, cpt.value AS optic_coating
    FROM catalog_product_entity_text cpt
    JOIN attribute_id_cte ac ON cpt.attribute_id = ac.attribute_id
    WHERE ac.attribute_code = 'optic_coating' AND cpt.store_id = 0
),
ddweapons_platform_data AS (
    SELECT cpi.entity_id, eov.value AS ddweapons_platform
    FROM Test1 cpi
    JOIN eav_attribute_option_value eov ON cpi.value = eov.option_id AND eov.store_id = 0
    WHERE cpi.attribute_id = 756 AND cpi.store_id = 0 
),

vendor_data AS (
    SELECT cpei.entity_id, ev.value AS vendor
    FROM catalog_product_entity_int cpei
    JOIN eav_attribute_option_value ev ON cpei.value = ev.option_id
    WHERE cpei.attribute_id = 145
),
Vendorpartscost AS (
    SELECT
        datelastmodified,
        partid,
        lastcost,
        ROW_NUMBER() OVER (PARTITION BY partid ORDER BY datelastmodified DESC) AS rn
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.VENDORPARTS
),
VendorLast AS ( 
SELECT
    datelastmodified,
    partid,
    lastcost
FROM
    Vendorpartscost
WHERE
    rn = 1),

Fishbowl_Conversion AS (
SELECT 
    pr.num, 
    AVG(uom.multiply) AS CONVERT,
    AVG(pc.avgcost) AS AVGCOST,
    AVG(vp.lastcost) AS LASTVENDORCOST


FROM
    AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT pr

LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1

LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.PARTCOST pc ON pr.partid = pc.partid

LEFT JOIN
    vendorlast vp ON pr.partid = vp.partid



Group BY
pr.num)



SELECT 
    e.entity_id AS "Product ID",
    e.sku,
    MAX(CASE WHEN va.attribute_code = 'name' THEN va.value END) AS "Product Name",
    MAX(CASE WHEN va.attribute_code = 'suggested_use' THEN va.value END) AS "General Purpose",
    MAX(CASE WHEN va.attribute_code = 'url_key' THEN CONCAT('https://www.ammunitiondepot.com/', va.value) END) AS "Product URL",
    MAX(CASE WHEN va.attribute_code = 'image' THEN CONCAT('https://www.ammunitiondepot.com/media/catalog/product', va.value) END) AS "Product Image URL",
    vd.vendor AS "Vendor",
    dd.discontinued AS "Discontinued",
    psd.parent_sku AS "Parent SKU",
    COALESCE(psd.parent_sku,e.sku) AS Grouped_SKU,
    MAX(CASE WHEN va.attribute_code = 'boxes_case' THEN va.value END) AS "Boxes/Case",
    MAX(CASE WHEN va.attribute_code = 'caliber' THEN va.value END) AS "Caliber",
    MAX(CASE WHEN va.attribute_code = 'manufacturer_sku' THEN va.value END) AS "Manufacturer SKU",
    MAX(CASE WHEN va.attribute_code = 'upc' THEN va.value END) AS "UPC",
    MAX(md.manufacturer) AS "Manufacturer",
    MAX(pd.projectile) AS "Projectile",
    MAX(utd.unit_type) AS "Unit Type",
    MAX(rpd.rounds_package) AS "Rounds/Package",
    MAX(asd.attribute_set_name) AS "Attribute Set",
    cd.categories AS "Categories",
    MAX(CASE WHEN va.attribute_code = 'gun_type' THEN va.value END) AS "Gun Type",
    MAX(ddc.ddcaliber) AS "DD Caliber",
    MAX(ddact.ddaction) AS "DD Gun Action",
    MAX(ddcond.ddcondition) AS "DD Condition",
    MAX(ddgp.ddgun_parts) AS "DD Gun Parts",
    MAX(capacity.capacity) AS "Capacity",
    MAX(material.material) AS "Material",
    MAX(pc.primary_category) AS "Primary Category",
    MAX(dc.ddcolor) AS "DD Color",
    MAX(oc.optic_coating) AS "Optic Coating",
    MAX(dwp.ddweapons_platform) AS "DD Weapons Platform",
    MAX(CASE WHEN va.attribute_code = 'thread_pattern' THEN va.value END) AS "Thread Pattern", -- Added column for thread_pattern
    MAX(CASE WHEN va.attribute_code = 'thread_type' THEN va.value END) AS "Thread Type", -- Added column for thread_type
    MAX(CASE WHEN va.attribute_code = 'model' THEN va.value END) AS "Model",
    Coalesce(MAX(fbc.CONVERT),1) AS CONVERT,
    MAX(fbc.avgcost) AS AVGCOST,
    MAX(fbc.LASTVENDORCOST) AS LASTVENDORCOST -- Added column for model
FROM 
    AD_AIRBYTE.TEST_DTO.catalog_product_entity e
LEFT JOIN varchar_attributes va ON e.entity_id = va.entity_id
LEFT JOIN int_attributes ia ON e.entity_id = ia.entity_id
LEFT JOIN decimal_attributes da ON e.entity_id = da.entity_id
LEFT JOIN text_attributes ta ON e.entity_id = ta.entity_id
LEFT JOIN category_data cd ON e.entity_id = cd.product_id
LEFT JOIN vendor_data vd ON e.entity_id = vd.entity_id
LEFT JOIN parent_sku_data psd ON e.entity_id = psd.product_id
LEFT JOIN discontinued_data dd ON e.entity_id = dd.entity_id
LEFT JOIN manufacturer_data md ON e.entity_id = md.entity_id
LEFT JOIN projectile_data pd ON e.entity_id = pd.entity_id
LEFT JOIN unit_type_data utd ON e.entity_id = utd.entity_id
LEFT JOIN ddcaliber_data ddc ON e.entity_id = ddc.entity_id
LEFT JOIN ddaction_data ddact ON e.entity_id = ddact.entity_id
LEFT JOIN ddcondition_data ddcond ON e.entity_id = ddcond.entity_id
LEFT JOIN ddgun_parts_data ddgp ON e.entity_id = ddgp.entity_id
LEFT JOIN rounds_package_data rpd ON e.entity_id = rpd.entity_id
LEFT JOIN capacity_data capacity ON e.entity_id = capacity.entity_id
LEFT JOIN material_data material ON e.entity_id = material.entity_id
LEFT JOIN attribute_set_data asd ON e.entity_id = asd.entity_id
LEFT JOIN primary_category_data pc ON e.entity_id = pc.entity_id
LEFT JOIN ddcolor_data dc ON e.entity_id = dc.entity_id
LEFT JOIN optic_coating_data oc ON e.entity_id = oc.entity_id
LEFT JOIN ddweapons_platform_data dwp ON e.entity_id = dwp.entity_id
LEFT JOIN FISHBOWL_CONVERSION fbc ON e.sku = fbc.num

GROUP BY e.entity_id, e.sku, cd.categories, vd.vendor, dd.discontinued, psd.parent_sku;

create or replace view AD_AIRBYTE.TEST_DTO.INVENTORYCONVERSION(
	PRODUCTID,
	KITPRODUCTID,
	INDIVIDUALNUM,
	DEFAULT,
	NUMBUNDLE,
	CONVERSIONRATE,
	KIT
) as
 
WITH 

KITS AS ( SELECT kt.productid,
kt.kitproductid,
pd.num AS individualnum,
kt.defaultqty as Default,
pt.num as  NUMBUNDLE FROM AD_AIRBYTE.AIRBYTE_SCHEMA.KITITEM kt
LEFT JOIN
AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT pd ON kt.productID = pd.id
LEFT JOIN
AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT pt ON kt.kitproductID = pt.id
 WHERE 
        kt.kittypeid = '10' AND pd.num NOT LIKE '%POLLYAMOBAG%'  AND pd.num NOT LIKE '%POLYAMMOBAG%'),


Fishbowl_Conversion AS (
SELECT 
    pr.num, 
    AVG(uom.multiply) AS CONVERT,
    AVG(pc.avgcost) AS AVGCOST


FROM
    AD_AIRBYTE.AIRBYTE_SCHEMA.PRODUCT pr

LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1

LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.PARTCOST pc ON pr.partid = pc.partid




Group BY
pr.num)







SELECT kt.*,
COALESCE(fc.Convert,1)*kt.default AS CONVERSIONRATE,
'KIT' AS KIT


FROM KITS kt
LEFT JOIN
FISHBOWL_CONVERSION fc ON kt.individualNUM = fc.num;

create or replace view AD_AIRBYTE.AIRBYTE_SCHEMA.D_VENDOR(
	_AIRBYTE_RAW_ID,
	_AIRBYTE_EXTRACTED_AT,
	_AIRBYTE_META,
	_AIRBYTE_GENERATION_ID,
	ID,
	URL,
	NAME,
	NOTE,
	LEADTIME,
	STATUSID,
	ACCOUNTID,
	SYSUSERID,
	TAXRATEID,
	ACCOUNTNUM,
	ACTIVEFLAG,
	CURRENCYID,
	CREDITLIMIT,
	DATEENTERED,
	ACCOUNTINGID,
	CURRENCYRATE,
	CUSTOMFIELDS,
	_AB_CDC_CURSOR,
	ACCOUNTINGHASH,
	MINORDERAMOUNT,
	_AB_CDC_LOG_POS,
	LASTCHANGEDUSER,
	_AB_CDC_LOG_FILE,
	DATELASTMODIFIED,
	DEFAULTCARRIERID,
	_AB_CDC_DELETED_AT,
	_AB_CDC_UPDATED_AT,
	DEFAULTSHIPTERMSID,
	DEFAULTPAYMENTTERMSID,
	DEFAULTCARRIERSERVICEID
) as 

SELECT 
 * 
FROM
vendor;

create or replace view AD_AIRBYTE.AIRBYTE_SCHEMA.F_INVENTORYVIEW(
	PART,
	"Vendor",
	"Name",
	"Part Qty Sold",
	"Total Revenue",
	"Part Qty Sold Per Week",
	"Part Qty Available",
	"Weeks on Hand",
	"Part Cost",
	"Extended Cost",
	"Qty on Order"
) as
WITH constants AS (
    SELECT
        TIMESTAMP '2021-01-01 04:00:00' AS start_date,
        CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_TIMESTAMP()) AS end_date,
        TIMESTAMP '2021-01-01 04:00:00' AS previous_start_date,
        CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_TIMESTAMP()) AS  previous_end_date
),
Transformation1 AS (


SELECT
    p.num AS Part,
    MAX(option_value.value) AS "Vendor",
    MAX(s.name) AS "Name",
    SUM(s.qty_ordered * COALESCE(uom.multiply, 1)) AS "Part Qty Sold",
    SUM(s.row_invoiced) AS "Total Revenue",
    (
        SELECT SUM(sub_s.qty_ordered * COALESCE(sub_uom.multiply, 1))
        FROM AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order_item sub_s
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order sub_o ON sub_s.order_id = sub_o.entity_id
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.catalog_product_entity sub_cpe ON sub_s.sku = sub_cpe.sku
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.product sub_pr ON sub_cpe.sku = sub_pr.num
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.part sub_p ON sub_pr.partid = sub_p.id
        LEFT JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion sub_uom ON sub_pr.uomid = sub_uom.fromuomid AND sub_uom.touomid = 1
        WHERE sub_p.num = p.num
        AND sub_o.created_at >= (SELECT previous_start_date FROM constants)
        AND sub_o.created_at < (SELECT previous_end_date FROM constants)
        AND sub_s.product_type <> 'bundle'
        AND sub_s.price > 0
    ) / (DATEDIFF('day', (SELECT previous_start_date FROM constants), (SELECT previous_end_date FROM constants)) / 7.0) AS "Part Qty Sold Per Week",
    qta."Part Qty Available",
    qta."Part Qty Available" / 
    (
        SELECT SUM(sub_s.qty_ordered * COALESCE(sub_uom.multiply, 1))
        FROM AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order_item sub_s
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order sub_o ON sub_s.order_id = sub_o.entity_id
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.catalog_product_entity sub_cpe ON sub_s.sku = sub_cpe.sku
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.product sub_pr ON sub_cpe.sku = sub_pr.num
        JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.part sub_p ON sub_pr.partid = sub_p.id
        LEFT JOIN AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion sub_uom ON sub_pr.uomid = sub_uom.fromuomid AND sub_uom.touomid = 1
        WHERE sub_p.num = p.num
        AND sub_o.created_at >= (SELECT previous_start_date FROM constants)
        AND sub_o.created_at < (SELECT previous_end_date FROM constants)
        AND sub_s.product_type <> 'bundle'
        AND sub_s.price > 0
    ) / (DATEDIFF('day', (SELECT previous_start_date FROM constants), (SELECT previous_end_date FROM constants)) / 7.0) AS "Weeks on Hand",
    MAX(pc.avgcost) AS "Part Cost",
    qta."Part Qty Available" * MAX(pc.avgcost) AS "Extended Cost",
    qta."Qty on Order"
FROM
    AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order_item s
JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.sales_order o ON s.order_id = o.entity_id
JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.catalog_product_entity cpe ON s.sku = cpe.sku
LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.catalog_product_entity_int option_value_vendor ON cpe.entity_id = option_value_vendor.entity_id AND option_value_vendor.attribute_id = 145
LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.eav_attribute_option_value option_value ON option_value_vendor.value = option_value.option_id AND option_value.store_id = 0
JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.product pr ON cpe.sku = pr.num
JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.part p ON pr.partid = p.id
LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion uom ON pr.uomid = uom.fromuomid AND uom.touomid = 1
LEFT JOIN (
    SELECT
        qit.partid,
        SUM(qit.qtyonhand) - SUM(qit.qtynotavailable) AS "Part Qty Available",
        SUM(qit.qtyonorder) AS "Qty on Order"
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.qtyinventorytotals qit
    GROUP BY
        qit.partid
) qta ON p.id = qta.partid
LEFT JOIN
    AD_AIRBYTE.AIRBYTE_SCHEMA.partcost pc ON p.id = pc.partid
WHERE
    o.created_at >= (SELECT start_date FROM constants)
    AND o.created_at <= (SELECT end_date FROM constants)
    AND s.product_type <> 'bundle'
    AND s.price > 0
GROUP BY
    p.num, qta."Part Qty Available", qta."Qty on Order"
ORDER BY
    SUM(s.row_invoiced) DESC)



SELECT * FROM
TRANSFORMATION1 t
;

create or replace view AD_AIRBYTE.TEST_DTO.F_SHIPPMENT(
	SHIPPING_AMOUNT,
	BASE_SHIPPING_AMOUNT,
	BASE_SHIPPING_CANCELED,
	BASE_SHIPPING_DISCOUNT_AMOUNT,
	BASE_SHIPPING_REFUNDED,
	BASE_SHIPPING_TAX_AMOUNT,
	BASE_SHIPPING_TAX_REFUNDED,
	ID,
	ORDER_ID,
	CUSTOMER_EMAIL,
	CARRIER_TYPE,
	CREATED_AT,
	CUSTOMER_NAME,
	BILLING_ADDRESS,
	SHIPPING_INFORMATION,
	STORE_ID,
	SHIPPING_DESCRIPTION,
	SHIPMENT_STATUS,
	SHIPPING_ADDRESS,
	SHIPPING_NAME,
	STATUS,
	SHIPPING_INFORMATION2,
	METHOD,
	CARRIER_TITLE,
	POSTCODE,
	COUNTRY,
	REGION,
	CITY,
	TELEPHONE,
	FREIGHTAMOUNT,
	NET_AMOUNT,
	PACKAGENUMB,
	FREIGHTWEIGHT,
	EXT_SHIPPING_INFO,
	ISFREE,
	CARRIERSERVICEID,
	ISFREEAUTO,
	IDCARRIER,
	CARRIERSERVICE
) as

WITH CODES AS (
    SELECT z.code AS CODE,
    MAX(METHOD) AS METHOD,
    MAX(CARRIER_TITLE) AS CARRIER_TITLE
    FROM QUOTE_SHIPPING_RATE z
    GROUP BY z.code
),

QUOTEFREE AS (
    SELECT 
    z.ADDRESS_ID AS ADDRESS_ID
    FROM QUOTE_SHIPPING_RATE z
    WHERE METHOD_TITLE LIKE '%Free%'
    GROUP BY z.ADDRESS_ID
),

FREEOPTIONS AS (
    SELECT 
    z.quote_id AS QUOTE_ID
    FROM QUOTE_ADDRESS z
    JOIN QUOTEFREE ty ON z.address_id = ty.Address_ID 
    GROUP BY z.quote_id
),



ADRESS AS (
    SELECT *
    FROM SALES_ORDER_ADDRESS
    WHERE address_type ='shipping'
),

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

Conversion AS (
    SELECT 
        f.recordId as ORDER_FISHBOWL,
        f.CHANNELID as ORDER_MAGENTO
    FROM AD_AIRBYTE.AIRBYTE_SCHEMA.PLUGININFO f
    WHERE f.TABLENAME = 'SO'
),

FreightInfo AS (
    SELECT 
    ty.order_magento as Order_magento,
    AVG(t.freightamount) as freightamount,
    AVG(t.freightweight) as freightweight,
    AVG(t.carrierserviceid) as CARRIERSERVICEID,
    AVG(t.AmountUPS) AS NET_AMOUNT,
   AVG(t.PACKAGENUMB) AS PACKAGENUMB

    FROM AD_AIRBYTE.AIRBYTE_SCHEMA.SO z
    LEFT JOIN SHIPTRANSFORMATION t ON TO_VARCHAR(z.id) = TO_VARCHAR(t.SOID)
    LEFT JOIN Conversion ty ON TO_VARCHAR(z.id) = TO_VARCHAR(ty.ORDER_FISHBOWL)
    GROUP BY ty.order_magento
),

SERVICE AS (
    SELECT 
    id as idCarrier,
    name as CarrierService
    FROM AD_AIRBYTE.AIRBYTE_SCHEMA.CARRIERSERVICE
),

F_SHIP AS (
    SELECT 
    Coalesce(ty.shipping_amount,0) as shipping_amount,
    coalesce(ty.base_shipping_amount,0) as base_shipping_amount,
    Coalesce(ty.base_shipping_canceled,0) as base_shipping_canceled,
    Coalesce(ty.base_shipping_discount_amount,0) AS base_shipping_discount_amount,
    coalesce(ty.base_shipping_refunded,0) AS base_shipping_refunded,
    Coalesce(ty.base_shipping_tax_amount,0) as base_shipping_tax_amount,
    Coalesce(ty.base_shipping_tax_refunded,0) AS base_shipping_tax_refunded,
    ty.increment_id AS ID,
    ty.entity_id AS ORDER_ID,
    ty.customer_email AS CUSTOMER_EMAIL,
    ty.carrier_type AS carrier_type,
    to_timestamp_ntz(CONVERT_TIMEZONE( 'America/New_York', TY.created_at)) AS CREATED_AT,
    Concat(ty.CUSTOMER_FIRSTNAME, ' ', ty.CUSTOMER_LASTNAME) AS CUSTOMER_NAME,
    ty.shipping_address_id AS BILLING_ADDRESS,
    ty.shipping_method AS SHIPPING_INFORMATION,
    ty.store_id AS STORE_ID,
    ty.shipping_description AS SHIPPING_DESCRIPTION,
    tz.shipment_status as shipment_status,
    tz.shipping_address as shipping_address,
    tz.shipping_name as shipping_name,
    ty.status as STATUS,
    tz.shipping_information as SHIPPING_INFORMATION2,
    z.method as METHOD,
    z.CARRIER_TITLE as CARRIER_TITLE,
    child.postcode as postcode,
    child.country_id as COUNTRY,
    child.region as REGION,
    child.city as CITY,
    child.telephone as telephone,
    zy.freightamount as Freightamount,
    zy.net_amount as net_amount,
    zy.PACKAGENUMB AS PACKAGENUMB,
    zy.freightweight as Freightweight,
    m.ext_shipping_info as ext_shipping_info,
    CASE WHEN ty.base_subtotal >= 140 THEN 'Yes' ELSE 'No' END AS ISFREE,
    zy.CARRIERSERVICEID as CARRIERSERVICEID,
    CASE WHEN tzy.quote_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS ISFREEAuto
    FROM SALES_ORDER ty 
    LEFT JOIN SALES_SHIPMENT_GRID tz ON TO_VARCHAR(ty.entity_id) = TO_VARCHAR(tz.order_id)
    LEFT JOIN CODES Z ON TO_VARCHAR(ty.shipping_method) = TO_VARCHAR(z.code)
    LEFT JOIN ADRESS child ON TO_VARCHAR(ty.SHIPPING_ADDRESS_ID) = TO_VARCHAR(child.entity_id)
    LEFT JOIN FreightInfo zy ON to_VARCHAR(ty.entity_id) = TO_VARCHAR(zy.order_magento)
    LEFT JOIN QUOTE m ON to_varchar(ty.quote_id) = to_varchar(m.entity_id)
    LEFT JOIN FREEOPTIONS tzy ON ty.quote_id = tzy.quote_id
)

SELECT * FROM F_SHIP z
LEFT JOIN SERVICE t ON to_varchar(z.CARRIERSERVICEID) = TO_VARCHAR(t.idcarrier);

create or replace view AD_AIRBYTE.TEST_DTO.D_STORE(
	_AIRBYTE_RAW_ID,
	_AIRBYTE_EXTRACTED_AT,
	_AIRBYTE_META,
	_AIRBYTE_GENERATION_ID,
	CODE,
	NAME,
	GROUP_ID,
	STORE_ID,
	IS_ACTIVE,
	SORT_ORDER,
	WEBSITE_ID,
	_AB_CDC_CURSOR,
	_AB_CDC_LOG_POS,
	_AB_CDC_LOG_FILE,
	_AB_CDC_DELETED_AT,
	_AB_CDC_UPDATED_AT
) as 
SELECT * 
FroM
STORE;

create or replace view PC_FIVETRAN_DB.MAGENTO_MYSQL_AMMUNITIONDEPOT_PROD2.D_USER(
	USER_ID,
	CREATED,
	ZENDESK_HASH,
	RP_TOKEN_CREATED_AT,
	MODIFIED,
	REFRESH_TOKEN,
	LOGDATE,
	EXTRA,
	RP_TOKEN,
	IS_ACTIVE,
	LASTNAME,
	RELOAD_ACL_FLAG,
	LOCK_EXPIRES,
	FIRST_FAILURE,
	EMAIL,
	INTERFACE_LOCALE,
	FIRSTNAME,
	USERNAME,
	LOGNUM,
	FAILURES_NUM,
	PASSWORD,
	_FIVETRAN_DELETED,
	_FIVETRAN_SYNCED
) as
SELECT * FROM ADMIN_USER;

create or replace view AD_AIRBYTE.TEST_DTO.D_CUSTOMERSEGMENTATION(
	CUSTOMER_EMAIL,
	RANK_ID,
	NUMBER_OF_PURCHASES,
	TOTAL_REVENUE,
	MARGIN,
	DAYS_SINCE_LAST_PURCHASE,
	TOTAL_PURCHASES_ALL_TIME,
	FREQUENCY,
	FREQUENCY_INT,
	RECENCY,
	RECENCY_INT,
	VALUE,
	VALUE_INT,
	MARGIN_CLASSIFICATION,
	MARGIN_INT,
	MONETARY_VALUE,
	CUSTOMER_CLASSIFICATION,
	CUSTOMER_GROUP
) as 

WITH Total_Purchases AS (
    SELECT 
        rank_id,
        COUNT(DISTINCT ORDER_ID) AS Total_Purchases_All_Time
    FROM 
        f_sales
    WHERE
        status IN ('PROCESSING', 'COMPLETE', 'UNVERIFIED')
    GROUP BY 
        rank_id
),

Customer_sales AS (
    SELECT 
        z.rank_id,
        COUNT(DISTINCT z.ORDER_ID) AS Number_of_Purchases,
        SUM(z.ROW_TOTAL) AS Total_Revenue,
        div0(SUM(z.ROW_TOTAL) - SUM(z.COST), SUM(z.ROW_TOTAL)) AS Margin,
        DATEDIFF(
            DAY, 
            MAX(z.CREATED_AT), 
            DATEADD(
                DAY, -1, 
                DATEFROMPARTS(
                    YEAR(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE)), 
                    MONTH(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE)), 
                    1
                )
            )
        ) AS Days_Since_Last_Purchase
    FROM
        f_sales z
    WHERE
        z.CREATED_AT >= DATEFROMPARTS(
            YEAR(DATEADD(YEAR, -1, CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE))), 
            MONTH(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE)), 
            1
        )
        AND z.CREATED_AT <= DATEADD(
            DAY, -1, 
            DATEFROMPARTS(
                YEAR(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE)), 
                MONTH(CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_DATE)), 
                1
            )
        )
        AND z.status IN ('PROCESSING', 'COMPLETE', 'UNVERIFIED')
    GROUP BY
        z.rank_id
),

d_customerupdatesview AS (
    SELECT 
        c.*,
        cs.Number_of_Purchases,
        cs.Total_Revenue,
        cs.Margin,
        cs.Days_Since_Last_Purchase,
        tp.Total_Purchases_All_Time,

        -- Frequency Calculation
        CASE 
            WHEN cs.Number_of_Purchases = 1 THEN 'F1'
            WHEN cs.Number_of_Purchases <= 2 THEN 'F2'
            WHEN cs.Number_of_Purchases <= 3 THEN 'F3'
            WHEN cs.Number_of_Purchases <= 5 THEN 'F4'
            WHEN cs.Number_of_Purchases >= 5 THEN 'F5'
            ELSE 'F0'
        END AS Frequency,

        -- Frequency Integer Calculation
        CASE 
            WHEN cs.Number_of_Purchases = 1 THEN 1
            WHEN cs.Number_of_Purchases <= 2 THEN 2
            WHEN cs.Number_of_Purchases <= 3 THEN 3
            WHEN cs.Number_of_Purchases <= 5 THEN 4
            WHEN cs.Number_of_Purchases >= 5 THEN 5
            ELSE 0
        END AS Frequency_Int,

        -- Recency Calculation
        CASE 
            WHEN cs.Days_Since_Last_Purchase <= 30 THEN 'R5'
            WHEN cs.Days_Since_Last_Purchase <= 60 THEN 'R4'
            WHEN cs.Days_Since_Last_Purchase <= 180 THEN 'R3'
            WHEN cs.Days_Since_Last_Purchase <= 240 THEN 'R2'
            WHEN cs.Days_Since_Last_Purchase <= 365 THEN 'R1'
            ELSE 'R0'
        END AS Recency,

        -- Recency Integer Calculation
        CASE 
            WHEN cs.Days_Since_Last_Purchase <= 30 THEN 5
            WHEN cs.Days_Since_Last_Purchase <= 60 THEN 4
            WHEN cs.Days_Since_Last_Purchase <= 120 THEN 3
            WHEN cs.Days_Since_Last_Purchase <= 180 THEN 2
            WHEN cs.Days_Since_Last_Purchase <= 365 THEN 1
            ELSE 0
        END AS Recency_Int,

        -- Value Calculation
        CASE 
            WHEN cs.Total_Revenue < 149 THEN 'V1'
            WHEN cs.Total_Revenue <= 225 THEN 'V2'
            WHEN cs.Total_Revenue <= 300 THEN 'V3'
            WHEN cs.Total_Revenue <= 500 THEN 'V4'
            WHEN cs.Total_Revenue > 500 THEN 'V5'
            ELSE 'V0'
        END AS Value,

        -- Value Integer Calculation
        CASE 
            WHEN cs.Total_Revenue < 149 THEN 1
            WHEN cs.Total_Revenue <= 225 THEN 2
            WHEN cs.Total_Revenue <= 300 THEN 3
            WHEN cs.Total_Revenue <= 500 THEN 4
            WHEN cs.Total_Revenue > 500 THEN 5
            ELSE 0
        END AS Value_Int,

        -- Margin Calculation
        CASE 
            WHEN cs.Margin < 0.20 THEN 'M1'
            WHEN cs.Margin < 0.24 THEN 'M2'
            WHEN cs.Margin < 0.26 THEN 'M3'
            WHEN cs.Margin < 0.30 THEN 'M4'
            WHEN cs.Margin >= 0.30 THEN 'M5'
            ELSE 'M0'
        END AS Margin_Classification,

        -- Margin Integer Calculation
        CASE 
            WHEN cs.Margin < 0.20 THEN 1
            WHEN cs.Margin < 0.24 THEN 2
            WHEN cs.Margin < 0.26 THEN 3
            WHEN cs.Margin < 0.30 THEN 4
            WHEN cs.Margin >= 0.30 THEN 5
            ELSE 0
        END AS Margin_Int

    FROM
        D_CUSTOMERUPDATED c
    LEFT JOIN
        Customer_sales cs ON c.rank_id = cs.rank_id
    LEFT JOIN
        Total_Purchases tp ON c.rank_id = tp.rank_id
),

Segmentation AS (
    SELECT 
        cs.*,

        -- Monetary Value (MV) Calculation: Average of Margin_Int and Value_Int rounded down
        CASE 
            WHEN FLOOR((cs.Margin_Int + cs.Value_Int) / 2) = 1 THEN 'MV1'
            WHEN FLOOR((cs.Margin_Int + cs.Value_Int) / 2) = 2 THEN 'MV2'
            WHEN FLOOR((cs.Margin_Int + cs.Value_Int) / 2) = 3 THEN 'MV3'
            WHEN FLOOR((cs.Margin_Int + cs.Value_Int) / 2) = 4 THEN 'MV4'
            WHEN FLOOR((cs.Margin_Int + cs.Value_Int) / 2) = 5 THEN 'MV5'
            ELSE 'MV0'
        END AS Monetary_Value,

        -- Customer Classification logic
        CASE 
            -- Super Engaged
            WHEN cs.Frequency = 'F5' AND cs.Recency = 'R5' THEN 'Super Engaged'
            -- Highly Engaged
            WHEN cs.Frequency = 'F4' AND cs.Recency = 'R5' THEN 'Highly Engaged'
            -- Active Loyalist
            WHEN cs.Frequency = 'F5' AND cs.Recency = 'R4' THEN 'Active Loyalist'
            -- Engaged Regular
            WHEN cs.Frequency = 'F4' AND cs.Recency = 'R4' THEN 'Engaged Regular'
            -- Regular w/Potential
            WHEN cs.Frequency = 'F3' AND (cs.Recency = 'R4' OR cs.Recency = 'R5') THEN 'Regular w/Potential'
            -- At-Risk Regular
            WHEN cs.Frequency IN ('F4', 'F5') AND cs.Recency = 'R3' THEN 'At-Risk Regular'
            -- Moderate Engager
            WHEN cs.Frequency = 'F3' AND cs.Recency = 'R3' THEN 'Moderate Engager'
            -- Relatively New Buyer
            WHEN cs.Frequency IN ('F1', 'F2') AND cs.Recency = 'R4' THEN 'Relatively New Buyer'
            -- New Buyer
            WHEN cs.Frequency = 'F1' AND cs.Recency = 'R5' THEN 'New Buyer'
            -- New Active Buyer
            WHEN cs.Frequency = 'F2' AND cs.Recency = 'R5' THEN 'New Active Buyer'
            -- Lapsed Buyer
            WHEN cs.Frequency IN ('F2', 'F3') AND cs.Recency IN ('R1', 'R2') THEN 'Lapsed Buyer'
            -- Inactive
            WHEN cs.Frequency = 'F1' AND cs.Recency = 'R1' THEN 'Inactive'
            -- Lost Buyer
            WHEN cs.Frequency IN ('F4', 'F5') AND cs.Recency = 'R1' THEN 'Lost Buyer'
            -- Losing 1-Time Buyer
            WHEN cs.Frequency = 'F1' AND cs.Recency IN ('R2', 'R3') THEN 'Losing 1-Time Buyer'
            -- Nurture Potential
            WHEN cs.Frequency = 'F2' AND cs.Recency = 'R3' THEN 'Nurture Potential'
            -- Inactive Regular
            WHEN cs.Frequency IN ('F4', 'F5') AND cs.Recency = 'R2' THEN 'Inactive Regular'
            ELSE 'Unclassified'
        END AS Customer_Classification

    FROM
        d_customerupdatesview cs
),
Customer_G AS (
SELECT DISTINCT
email,
customer_group_code

FROM
CUSTOMER_ENTITY z
LEFT JOIN
PC_FIVETRAN_DB.MAGENTO_MYSQL_AMMUNITIONDEPOT_PROD2.CUSTOMER_GROUP t ON z.group_id = t.customer_group_id)


SELECT
    t.*,
  coalesce(g.customer_group_code, 'Not Registered') AS Customer_Group

FROM
    Segmentation t
LEFT JOIN
CUSTOMER_G g ON t.customer_email = g.email


WHERE 
    CUSTOMER_CLASSIFICATION <> '';

create or replace view AD_AIRBYTE.TEST_DTO.D_CUSTOMERUPDATED(
	CUSTOMER_EMAIL,
	RANK_ID
) as 
WITH CleanedEmails AS (
    SELECT 
        LOWER(COALESCE(NULLIF(CUSTOMER_EMAIL, ''), 'customer@nonidentified.com')) AS CUSTOMER_EMAIL
    FROM 
        SALES_ORDER
),
DistinctEmails AS (
    SELECT DISTINCT 
        CUSTOMER_EMAIL
    FROM 
        CleanedEmails
)
SELECT 
    CUSTOMER_EMAIL,
    ROW_NUMBER() OVER (ORDER BY CUSTOMER_EMAIL) AS RANK_ID
FROM 
    DistinctEmails;


create or replace view AD_AIRBYTE.AIRBYTE_SCHEMA.F_POS(
	PARTID,
	IDID,
	LOCATIONGROUPID,
	QTY,
	DATERECONCILED,
	NUM,
	DATERECEIVED,
	DATELASTMODIFIED,
	UNITCOST,
	TOTALCOST,
	DATELASTFULFILLMENT,
	DATESCHEDULEDFULFILLMENT,
	QTYFULFILLED,
	QTYTOFULFILL,
	VENDORID,
	DATECREATED,
	DATECONFIRMED,
	DATEISSUED,
	DATEFIRSTSHIP,
	POID,
	STATUSID,
	POITEMID,
	LASTDATEPRIORTORECEIVED,
	VENDORLEADTIME,
	VENDORPRODUCTLEADTIME,
	PRODUCTLEADTIME,
	PRECISELEADTIME,
	DATEEXPECTED
) as
WITH OrdersBreak AS (
    SELECT 
        poi.id,
        poi.unitcost,
        poi.totalcost,
        poi.datelastfulfillment,
        poi.datescheduledfulfillment,
        poi.qtyfulfilled,
        poi.qtytofulfill,
        p.vendorid,
        p.datecreated,
        p.dateconfirmed,
        p.dateissued,
        p.datefirstship,
        poi.poid
    FROM POITEM poi
    LEFT JOIN PO p 
           ON poi.poid = p.id
    ORDER BY poi.datelastfulfillment DESC
),

/*--------------------------------------------------------------------------
   1) Your "base" query that does the GROUP BY and the main aggregations.
   2) We remove the ORDER BY here, because we’ll do it in the final SELECT.
 ---------------------------------------------------------------------------*/
f_pos_base AS (
    SELECT
        AD_AIRBYTE.AIRBYTE_SCHEMA.part.id AS PARTID,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.id AS IDID,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receipt.locationGroupId AS LOCATIONGROUPID,
        SUM(
            COALESCE(
                CASE
                    WHEN (AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.uomId
                          <> AD_AIRBYTE.AIRBYTE_SCHEMA.part.uomId)
                      AND (AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion.id > 0)
                    THEN
                         (AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.qty
                           * AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion.multiply)
                         / AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion.factor
                    ELSE
                        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.qty
                END,
            0)
        ) AS QTY,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereconciled,
        AD_AIRBYTE.AIRBYTE_SCHEMA.part.num,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereceived,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datelastmodified,
        ob.unitcost,
        SUM(ob.totalcost) AS totalcost,
        ob.datelastfulfillment,
        ob.datescheduledfulfillment,
        SUM(ob.qtyfulfilled) AS qtyfulfilled,
        SUM(ob.qtytofulfill) AS qtytofulfill,
        ob.vendorid,
        ob.datecreated,
        ob.dateconfirmed,
        ob.dateissued,
        ob.datefirstship,
        ob.poid,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.statusId,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.POitemID,
        -- Use LAG to get prior receipt date; fall back to PO datecreated if no prior
        COALESCE(
            LAG(AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereceived)
                OVER (
                    PARTITION BY AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.POitemID
                    ORDER BY AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereceived ASC
                ),
            ob.datecreated
        ) AS LastDatePriorToReceived
    FROM
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem
    JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.receipt
            ON AD_AIRBYTE.AIRBYTE_SCHEMA.receipt.id
               = AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.receiptId
    JOIN
        OrdersBreak ob
            ON AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.poitemid = ob.id
    JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.part
            ON AD_AIRBYTE.AIRBYTE_SCHEMA.part.id
               = AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.partId
    LEFT JOIN
        AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion
            ON AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion.toUomId
               = AD_AIRBYTE.AIRBYTE_SCHEMA.part.uomId
           AND AD_AIRBYTE.AIRBYTE_SCHEMA.uomconversion.fromUomId
               = AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.uomId
    WHERE
        AD_AIRBYTE.AIRBYTE_SCHEMA.receipt.orderTypeId = 10
        AND (AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.statusId = 10
             OR AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.statusId = 40)
    GROUP BY
        AD_AIRBYTE.AIRBYTE_SCHEMA.part.id,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.id,
        AD_AIRBYTE.AIRBYTE_SCHEMA.part.num,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receipt.locationGroupId,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereconciled,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datereceived,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.datelastmodified,
        ob.unitcost,
        ob.datelastfulfillment,
        ob.datescheduledfulfillment,
        ob.vendorid,
        ob.datecreated,
        ob.dateconfirmed,
        ob.dateissued,
        ob.datefirstship,
        ob.poid,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.statusId,
        AD_AIRBYTE.AIRBYTE_SCHEMA.receiptitem.POitemID
),

/*--------------------------------------------------------------------------
   Final step: compute
   - Truncated dates
   - leadTimeDays = difference in days between those dates
   - AVERAGE(leadTimeDays) over the last 3 POs by (vendorid, part.num)
   - Round up that average
   - lastDatePriorToReceived + averageLeadTimeDays3posRoundedUp
 ---------------------------------------------------------------------------*/

RANK3CTE AS (SELECT
    POID,
    vendorid,
    num,
    datereceived,
    LastDatePriorToReceived,
    DATEDIFF(day, LastDatePriorToReceived, datereceived) AS DateDifference
FROM (
    SELECT
        POID,
        vendorid,
        num,
        datereceived,
        LastDatePriorToReceived,
        ROW_NUMBER() OVER (
            PARTITION BY vendorid, num
            ORDER BY datereceived DESC
        ) AS rn
    FROM f_pos_base
    WHERE datereceived IS NOT NULL
) AS sub
WHERE rn <= 3),


LT AS (
SELECT CONCAT(Vendorid, '@', Num) AS Keymain,
CEIL(AVG(DateDifference))  AS LT
FROM
RANK3CTE
GROUP BY
vendorid,
num),

RANK3CTEvendor  AS (SELECT
    POID,
    vendorid,
    datereceived,
    LastDatePriorToReceived,
    DATEDIFF(day, LastDatePriorToReceived, datereceived) AS DateDifference
FROM (
    SELECT
        POID,
        vendorid,
        datereceived,
        LastDatePriorToReceived,
        ROW_NUMBER() OVER (
            PARTITION BY vendorid
            ORDER BY datereceived DESC
        ) AS rn
    FROM f_pos_base
    WHERE datereceived IS NOT NULL
) AS sub
WHERE rn <= 3),


LTVENDOR AS (
SELECT Vendorid AS Keymain,
CEIL(AVG(DateDifference))  AS LT
FROM
RANK3CTE
GROUP BY
vendorid),
RANK3CTENUM  AS (SELECT
    POID,
    num,
    datereceived,
    LastDatePriorToReceived,
    DATEDIFF(day, LastDatePriorToReceived, datereceived) AS DateDifference
FROM (
    SELECT
        POID,
        num,
        datereceived,
        LastDatePriorToReceived,
        ROW_NUMBER() OVER (
            PARTITION BY num
            ORDER BY datereceived DESC
        ) AS rn
    FROM f_pos_base
    WHERE datereceived IS NOT NULL
) AS sub
WHERE rn <= 3),


LTNUM AS (
SELECT num AS Keymain,
CEIL(AVG(DateDifference))  AS LT
FROM
RANK3CTE
GROUP BY
num)



SELECT 
fp.*,
lv.lt AS VendorLeadTime,
l.lt AS VendorProductLeadtime,
lnum.lt AS ProductLeadtime,
COALESCE(l.lt, lv.lt, lnum.lt) AS PreciseLeadtime,
  DATEADD(day, COALESCE(l.lt, lv.lt, lnum.lt), LastDatePriorToReceived) AS dateexpected

FROM
f_pos_base fp
LEFT JOIN
LT l ON CONCAT(fp.vendorid, '@', fp.num) = l.keymain
LEFT JOIN
LTVENDOR lv ON fp.vendorid = lv.keymain
LEFT JOIN
LTNUM lnum ON fp.num = lnum.keymain







;