{{ config(
    materialized = 'view',
    schema       = 'gold'
) }}

WITH 

codes AS (
    SELECT
        z.code                         AS code,
        MAX(z.method)                  AS method,
        MAX(z.carrier_title)           AS carrier_title
    FROM {{ source('magento','quote_shipping_rate') }} AS z
    GROUP BY z.code
),

quotefree AS (
    SELECT
        z.address_id                   AS address_id
    FROM {{ source('magento','quote_shipping_rate') }} AS z
    WHERE z.method_title ILIKE '%Free%'
    GROUP BY z.address_id
),

freeoptions AS (
    SELECT
        a.quote_id                     AS quote_id
    FROM {{ source('magento','quote_address') }} AS a
    JOIN quotefree                   AS qf ON a.address_id = qf.address_id
    GROUP BY a.quote_id
),

address AS (
    SELECT *
    FROM {{ source('magento','sales_order_address') }}
    WHERE address_type = 'shipping'
),

newship AS (
    SELECT
        tracking_number                AS tracking_number,
        SUM(net_amount)                AS net_amount
    FROM {{ source('magento','ups_invoice') }}
    GROUP BY tracking_number
),

shiptransformation AS (
    SELECT
        s.soid                         AS soid,
        COALESCE(SUM(ns.net_amount), SUM(sc.freightamount)) AS freightamount,
        SUM(sc.freightweight)          AS freightweight,
        AVG(s.carrierserviceid)        AS carrierserviceid,
        SUM(ns.net_amount)             AS amountups,
        COUNT(sc.trackingnum)          AS packagenumb
    FROM {{ source('fishbowl','fishbowl_ship') }}           AS s
    LEFT JOIN {{ source('fishbowl','fishbowl_shipcarton') }} AS sc ON s.id = sc.shipid
    LEFT JOIN newship                              AS ns ON sc.trackingnum = ns.tracking_number
    GROUP BY s.soid
),

conversion AS (
    SELECT
        p.recordid                    AS order_fishbowl,
        p.channelid                   AS order_magento
    FROM {{ source('fishbowl','fishbowl_plugininfo') }} AS p
    WHERE p.tablename = 'SO'
),

freightinfo AS (
    SELECT
        c.order_magento               AS order_magento,
        AVG(st.freightamount)         AS freightamount,
        AVG(st.freightweight)         AS freightweight,
        AVG(st.carrierserviceid)      AS carrierserviceid,
        AVG(st.amountups)             AS net_amount,
        AVG(st.packagenumb)           AS packagenumb
    FROM {{ source('fishbowl','so') }}            AS so
    LEFT JOIN shiptransformation                   AS st ON TO_VARCHAR(so.id) = TO_VARCHAR(st.soid)
    LEFT JOIN conversion                           AS c  ON TO_VARCHAR(so.id) = TO_VARCHAR(c.order_fishbowl)
    GROUP BY c.order_magento
),

service AS (
    SELECT
        cs.idcarrier                   AS idcarrier,
        cs.carrierservice              AS carrierservice
    FROM {{ source('magento','carrierservice') }} AS cs
),

f_ship AS (
    SELECT
        COALESCE(so.shipping_amount, 0)              AS shipping_amount,
        COALESCE(so.base_shipping_amount, 0)         AS base_shipping_amount,
        COALESCE(so.base_shipping_canceled, 0)       AS base_shipping_canceled,
        COALESCE(so.base_shipping_discount_amount,0) AS base_shipping_discount_amount,
        COALESCE(so.base_shipping_refunded,0)        AS base_shipping_refunded,
        COALESCE(so.base_shipping_tax_amount,0)      AS base_shipping_tax_amount,
        COALESCE(so.base_shipping_tax_refunded,0)    AS base_shipping_tax_refunded,
        so.increment_id                              AS id,
        so.entity_id                                 AS order_id,
        so.customer_email                            AS customer_email,
        so.carrier_type,
        TO_TIMESTAMP_NTZ(CONVERT_TIMEZONE(
          'UTC','America/New_York',so.created_at
        ))                                            AS created_at,
        CONCAT(so.customer_firstname,' ',so.customer_lastname)
                                                     AS customer_name,
        so.shipping_address_id                       AS billing_address,
        so.shipping_method                           AS shipping_information,
        so.store_id                                  AS store_id,
        so.shipping_description                      AS shipping_description,
        sg.shipment_status                           AS shipment_status,
        sg.shipping_address                          AS shipping_address,
        sg.shipping_name                             AS shipping_name,
        so.status                                    AS status,
        sg.shipping_information                      AS shipping_information2,
        c.method,
        c.carrier_title,
        a.postcode,
        a.country_id                                 AS country,
        a.region,
        a.city,
        a.telephone,
        fi.freightamount,
        fi.net_amount,
        fi.packagenumb                               AS packagenumb,
        fi.freightweight                             AS freightweight,
        q.ext_shipping_info                          AS ext_shipping_info,
        CASE WHEN so.base_subtotal >= 140 THEN 'Yes' ELSE 'No' END
                                                     AS isfree,
        fi.carrierserviceid                          AS carrierserviceid,
        CASE WHEN fo.quote_id IS NOT NULL THEN 'Yes' ELSE 'No' END
                                                     AS isfreeauto
    FROM {{ source('magento','sales_order') }}            AS so
    LEFT JOIN {{ source('magento','sales_shipment_grid') }} AS sg
      ON TO_VARCHAR(so.entity_id) = TO_VARCHAR(sg.order_id)
    LEFT JOIN codes                                        AS c
      ON TO_VARCHAR(so.shipping_method) = TO_VARCHAR(c.code)
    LEFT JOIN address                                     AS a
      ON TO_VARCHAR(so.shipping_address_id) = TO_VARCHAR(a.entity_id)
    LEFT JOIN freightinfo                                AS fi
      ON TO_VARCHAR(so.entity_id) = TO_VARCHAR(fi.order_magento)
    LEFT JOIN {{ source('magento','quote') }}              AS q
      ON TO_VARCHAR(so.quote_id) = TO_VARCHAR(q.entity_id)
    LEFT JOIN freeoptions                                 AS fo
      ON so.quote_id = fo.quote_id
)

SELECT
    fs.*,
    svc.carrierservice
FROM f_ship AS fs
LEFT JOIN service AS svc
  ON TO_VARCHAR(fs.carrierserviceid) = TO_VARCHAR(svc.idcarrier)
