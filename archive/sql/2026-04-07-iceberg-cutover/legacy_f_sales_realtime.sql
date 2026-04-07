-- Rollback DDL for AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME
-- Captured 2026-04-07 21:25 UTC before rewrite.

use role transformer_role;
use warehouse etl_wh;

create or replace view F_SALES_REALTIME(
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
) COMMENT='pre-rewrite ownership test 2026-04-07 21:24'
 as

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
ORDER BY l.CREATED_AT DESC;;
