{{ config(
    materialized = 'table',
    schema       = 'gold'
) }}

WITH 

codes AS (
    SELECT
        z.quote_shipping_rate_code                   AS code,
        MAX(z.method)            AS method,
        MAX(z.carrier_title)     AS carrier_title
    FROM {{ ref('magento_quote_shipping_rate') }} AS z
    GROUP BY z.quote_shipping_rate_code
),

quotefree AS (
    SELECT
        z.quote_address_id             AS address_id
    FROM {{ ref('magento_quote_shipping_rate') }} AS z
    WHERE z.method_title ILIKE '%Free%'
    GROUP BY z.quote_address_id
),

freeoptions AS (
    SELECT
        a.quote_id               AS quote_id
    FROM {{ ref('magento_quote_address') }} AS a
    JOIN quotefree              AS qf
      ON a.quote_address_id = qf.address_id
    GROUP BY a.quote_id
),

address AS (
    SELECT *
    FROM {{ ref('magento_sales_order_address') }}
    WHERE address_type = 'shipping'
),

newship AS (
    SELECT
        tracking_number          AS tracking_number,
        SUM(net_amount)          AS net_amount
    FROM {{ source('magento','ups_invoice') }}
    GROUP BY tracking_number
),

shiptransformation AS (
    SELECT
        s.shipment_id                   AS soid,
        COALESCE(SUM(ns.net_amount), SUM(sc.freight_weight)) AS freightamount,
        SUM(sc.freight_weight)    AS freightweight,
        AVG(s.carrier_service_id)  AS carrierserviceid,
        SUM(ns.net_amount)       AS net_amount,
        COUNT(sc.tracking_number)    AS packagenumb
    FROM {{ ref('fishbowl_ship') }}            AS s
    LEFT JOIN {{ ref('fishbowl_shipcarton') }} AS sc
      ON s.shipment_id = sc.shipment_id
    LEFT JOIN newship                              AS ns
      ON sc.tracking_number = ns.tracking_number
    GROUP BY s.shipment_id
),

conversion AS (
    SELECT
        p.record_id              AS order_fishbowl,
        p.channel_id             AS order_magento
    FROM {{ ref('fishbowl_plugininfo') }} AS p
    WHERE p.related_table_name = 'SO'
),

freightinfo AS (
    SELECT
        c.order_magento         AS order_magento,
        AVG(st.freightamount)   AS freightamount,
        AVG(st.freightweight)   AS freightweight,
        AVG(st.carrierserviceid) AS carrierserviceid,
        AVG(st.net_amount)      AS net_amount,
        AVG(st.packagenumb)     AS packagenumb
    FROM {{ ref('fishbowl_so') }} AS so
    LEFT JOIN shiptransformation AS st
      ON CAST(so.sales_order_id   AS VARCHAR) = CAST(st.soid             AS VARCHAR)
    LEFT JOIN conversion        AS c
      ON CAST(so.sales_order_id   AS VARCHAR) = CAST(c.order_fishbowl   AS VARCHAR)
    GROUP BY c.order_magento
),

service AS (
    SELECT
        cs.carrier_id            AS idcarrier,
        cs.carrier_service_name       AS carrierservice
    FROM {{ ref('fishbowl_carrierservice') }} AS cs
),

f_ship AS (
    SELECT
        COALESCE(so.shipping_amount, 0)              AS SHIPPING_AMOUNT,
        COALESCE(so.base_shipping_amount, 0)         AS BASE_SHIPPING_AMOUNT,
        COALESCE(so.base_shipping_canceled, 0)       AS BASE_SHIPPING_CANCELED,
        COALESCE(so.base_shipping_discount_amount, 0) AS BASE_SHIPPING_DISCOUNT_AMOUNT,
        COALESCE(so.base_shipping_refunded, 0)       AS BASE_SHIPPING_REFUNDED,
        COALESCE(so.base_shipping_tax_amount, 0)     AS BASE_SHIPPING_TAX_AMOUNT,
        COALESCE(so.base_shipping_tax_refunded, 0)   AS BASE_SHIPPING_TAX_REFUNDED,
        so.order_increment_id                       AS ID,
        so.order_id                                 AS ORDER_ID,
        so.customer_email                           AS CUSTOMER_EMAIL,
        so.carrier_type                             AS CARRIER_TYPE,
        CONVERT_TIMEZONE(
            'UTC',
            'America/New_York',
            CAST(so.created_at AS timestamp)
        )                                           AS CREATED_AT,
        so.customer_firstname
        || ' '
        || so.customer_lastname                     AS CUSTOMER_NAME,
        so.shipping_address_id                      AS BILLING_ADDRESS,
        so.shipping_method                          AS SHIPPING_INFORMATION,
        so.store_id                                 AS STORE_ID,
        so.shipping_description                     AS SHIPPING_DESCRIPTION,
        sg.shipment_status_code                     AS SHIPMENT_STATUS,
        sg.shipping_address_text                    AS SHIPPING_ADDRESS,
        sg.shipping_name                            AS SHIPPING_NAME,
        so.order_status                             AS STATUS,
        sg.shipping_information                     AS SHIPPING_INFORMATION2,
        c.method                                    AS METHOD,
        c.carrier_title                             AS CARRIER_TITLE,
        addr.postcode                               AS POSTCODE,
        addr.country_code                           AS COUNTRY,
        addr.region                                 AS REGION,
        addr.city                                   AS CITY,
        addr.phone_number                           AS TELEPHONE,
        fi.freightamount                            AS FREIGHTAMOUNT,
        fi.net_amount                               AS NET_AMOUNT,
        fi.packagenumb                              AS PACKAGENUMB,
        fi.freightweight                            AS FREIGHTWEIGHT,
        q.ext_shipping_info                         AS EXT_SHIPPING_INFO,
        CASE WHEN so.base_subtotal >= 140 THEN 'Yes' ELSE 'No' END
                                                   AS ISFREE,
        fi.carrierserviceid                         AS CARRIERSERVICEID,
        CASE WHEN fo.quote_id IS NOT NULL THEN 'Yes' ELSE 'No' END
                                                   AS ISFREEAUTO
    FROM {{ ref('magento_sales_order') }}               AS so
    LEFT JOIN {{ ref('magento_sales_shipment_grid') }}  AS sg
      ON CAST(so.order_id           AS VARCHAR) = CAST(sg.order_id           AS VARCHAR)
    LEFT JOIN codes                                   AS c
      ON CAST(so.shipping_method     AS VARCHAR) = CAST(c.code                 AS VARCHAR)
    LEFT JOIN address                                AS addr
      ON CAST(so.shipping_address_id AS VARCHAR) = CAST(addr.order_address_id AS VARCHAR)
    LEFT JOIN freightinfo                            AS fi
      ON CAST(so.order_id           AS VARCHAR) = CAST(fi.order_magento       AS VARCHAR)
    LEFT JOIN {{ ref('magento_quote') }}              AS q
      ON CAST(so.quote_id            AS VARCHAR) = CAST(q.entity_id            AS VARCHAR)
    LEFT JOIN freeoptions                             AS fo
      ON so.quote_id = fo.quote_id
)

SELECT
    fs.SHIPPING_AMOUNT,
    fs.BASE_SHIPPING_AMOUNT,
    fs.BASE_SHIPPING_CANCELED,
    fs.BASE_SHIPPING_DISCOUNT_AMOUNT,
    fs.BASE_SHIPPING_REFUNDED,
    fs.BASE_SHIPPING_TAX_AMOUNT,
    fs.BASE_SHIPPING_TAX_REFUNDED,
    fs.ID,
    fs.ORDER_ID,
    fs.CUSTOMER_EMAIL,
    fs.CARRIER_TYPE,
    fs.CREATED_AT,
    fs.CUSTOMER_NAME,
    fs.BILLING_ADDRESS,
    fs.SHIPPING_INFORMATION,
    fs.STORE_ID,
    fs.SHIPPING_DESCRIPTION,
    fs.SHIPMENT_STATUS,
    fs.SHIPPING_ADDRESS,
    fs.SHIPPING_NAME,
    fs.STATUS,
    fs.SHIPPING_INFORMATION2,
    fs.METHOD,
    fs.CARRIER_TITLE,
    fs.POSTCODE,
    fs.COUNTRY,
    fs.REGION,
    fs.CITY,
    fs.TELEPHONE,
    fs.FREIGHTAMOUNT,
    fs.NET_AMOUNT,
    fs.PACKAGENUMB,
    fs.FREIGHTWEIGHT,
    fs.EXT_SHIPPING_INFO,
    fs.ISFREE,
    fs.CARRIERSERVICEID,
    fs.ISFREEAUTO,
    svc.idcarrier   AS IDCARRIER,
    svc.carrierservice AS CARRIERSERVICE
FROM f_ship AS fs
LEFT JOIN service AS svc
  ON CAST(fs.CARRIERSERVICEID   AS VARCHAR) = CAST(svc.idcarrier      AS VARCHAR)