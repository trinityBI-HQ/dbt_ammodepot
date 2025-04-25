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
        COALESCE(so.shipping_amount, 0)              AS shipping_amount,
        COALESCE(so.base_shipping_amount, 0)         AS base_shipping_amount,
        COALESCE(so.base_shipping_canceled, 0)       AS base_shipping_canceled,
        COALESCE(so.base_shipping_discount_amount, 0) AS base_shipping_discount_amount,
        COALESCE(so.base_shipping_refunded, 0)       AS base_shipping_refunded,
        COALESCE(so.base_shipping_tax_amount, 0)     AS base_shipping_tax_amount,
        COALESCE(so.base_shipping_tax_refunded, 0)   AS base_shipping_tax_refunded,
        so.order_increment_id                             AS id,
        so.order_id                                AS order_id,
        so.customer_email                           AS customer_email,
        so.carrier_type                             AS carrier_type,
        CONVERT_TIMEZONE(
        'UTC',
        'America/New_York',
        CAST(so.created_at AS timestamp)
        )                                           AS created_at,
        so.customer_firstname
        || ' '
        || so.customer_lastname          AS customer_name,
        so.shipping_address_id                     AS billing_address,
        so.shipping_method                         AS shipping_information,
        so.store_id                                AS store_id,
        so.shipping_description                    AS shipping_description,
        sg.shipment_status_code                         AS shipment_status,
        sg.shipping_address_text                        AS shipping_address,
        sg.shipping_name                           AS shipping_name,
        so.order_status                                  AS status,
        sg.shipping_information                    AS shipping_information2,
        c.method                                   AS method,
        c.carrier_title                            AS carrier_title,
        addr.postcode                              AS postcode,
        addr.country_code                            AS country,
        addr.region                                AS region,
        addr.city                                  AS city,
        addr.phone_number                             AS telephone,
        fi.freightamount                           AS freightamount,
        fi.net_amount                              AS net_amount,
        fi.packagenumb                             AS packagenumb,
        fi.freightweight                           AS freightweight,
        q.ext_shipping_info                        AS ext_shipping_info,
        CASE WHEN so.base_subtotal >= 140 THEN 'Yes' ELSE 'No' END
                                                  AS is_free,
        fi.carrierserviceid                        AS carrierserviceid,
        CASE WHEN fo.quote_id IS NOT NULL THEN 'Yes' ELSE 'No' END
                                                  AS is_free_auto
    FROM {{ ref('magento_sales_order') }}               AS so
    LEFT JOIN {{ ref('magento_sales_shipment_grid') }}  AS sg
      ON CAST(so.order_id           AS VARCHAR) = CAST(sg.order_id           AS VARCHAR)
    LEFT JOIN codes                                   AS c
      ON CAST(so.shipping_method     AS VARCHAR) = CAST(c.code                 AS VARCHAR)
    LEFT JOIN address                                AS addr
      ON CAST(so.shipping_address_id AS VARCHAR) = CAST(addr.order_address_id         AS VARCHAR)
    LEFT JOIN freightinfo                            AS fi
      ON CAST(so.order_id           AS VARCHAR) = CAST(fi.order_magento       AS VARCHAR)
    LEFT JOIN {{ ref('magento_quote') }}              AS q
      ON CAST(so.quote_id            AS VARCHAR) = CAST(q.entity_id            AS VARCHAR)
    LEFT JOIN freeoptions                             AS fo
      ON so.quote_id = fo.quote_id
)

SELECT
    fs.*,
    svc.carrierservice
FROM f_ship AS fs
LEFT JOIN service AS svc
  ON CAST(fs.carrierserviceid     AS VARCHAR) = CAST(svc.idcarrier          AS VARCHAR)
