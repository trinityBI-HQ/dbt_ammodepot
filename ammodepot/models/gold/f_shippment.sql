with

codes as (
    select
        z.quote_shipping_rate_code                   as code,
        max(z.method)            as method,
        max(z.carrier_title)     as carrier_title
    from {{ ref('magento_quote_shipping_rate') }} as z
    group by z.quote_shipping_rate_code
),

quotefree as (
    select
        z.quote_address_id             as address_id
    from {{ ref('magento_quote_shipping_rate') }} as z
    where z.method_title ilike '%Free%'
    group by z.quote_address_id
),

freeoptions as (
    select
        a.quote_id               as quote_id
    from {{ ref('magento_quote_address') }} as a
    inner join quotefree              as qf
      on a.quote_address_id = qf.address_id
    group by a.quote_id
),

address as (
    select
        order_address_id,
        order_id,
        postcode,
        country_code,
        region,
        city,
        phone_number
    from {{ ref('magento_sales_order_address') }}
    where address_type = 'shipping'
),

newship as (
    select
        tracking_number          as tracking_number,
        sum(net_amount)          as net_amount
    from {{ ref('magento_ups_invoice') }}
    group by tracking_number
),

shiptransformation as (
    select
        s.shipment_id                   as soid,
        s.sales_order_id as sales_order_id,
        coalesce(sum(ns.net_amount), sum(sc.freight_weight)) as freightamount,
        sum(sc.freight_weight)    as freightweight,
        avg(s.carrier_service_id)  as carrierserviceid,
        sum(ns.net_amount)       as net_amount,
        count(sc.tracking_number)    as packagenumb
    from {{ ref('fishbowl_ship') }}            as s
    left join {{ ref('fishbowl_shipcarton') }} as sc
      on s.shipment_id = sc.shipment_id
    left join newship                              as ns
      on sc.tracking_number = ns.tracking_number
    group by s.shipment_id, sales_order_id
),

conversion as (
    select
        p.record_id              as order_fishbowl,
        p.channel_id             as order_magento
    from {{ ref('fishbowl_plugininfo') }} as p
    where p.related_table_name = 'SO'
),

freightinfo as (
    select
        c.order_magento         as order_magento,
        avg(st.freightamount)   as freightamount,
        avg(st.freightweight)   as freightweight,
        avg(st.carrierserviceid) as carrierserviceid,
        avg(st.net_amount)      as net_amount,
        avg(st.packagenumb)     as packagenumb
    from {{ ref('fishbowl_so') }} as so
    left join shiptransformation as st
    on cast(so.sales_order_id as varchar) = cast(st.sales_order_id as varchar)
    left join conversion        as c
      on cast(so.sales_order_id   as varchar) = cast(c.order_fishbowl   as varchar)
    group by c.order_magento
),

service as (
    select
        cs.carrier_id            as idcarrier,
        cs.carrier_service_name       as carrierservice
    from {{ ref('fishbowl_carrierservice') }} as cs
),

f_ship as (
    select
        coalesce(so.shipping_amount, 0)              as SHIPPING_AMOUNT,
        coalesce(so.base_shipping_amount, 0)         as BASE_SHIPPING_AMOUNT,
        coalesce(so.base_shipping_canceled, 0)       as BASE_SHIPPING_CANCELED,
        coalesce(so.base_shipping_discount_amount, 0) as BASE_SHIPPING_DISCOUNT_AMOUNT,
        coalesce(so.base_shipping_refunded, 0)       as BASE_SHIPPING_REFUNDED,
        coalesce(so.base_shipping_tax_amount, 0)     as BASE_SHIPPING_TAX_AMOUNT,
        coalesce(so.base_shipping_tax_refunded, 0)   as BASE_SHIPPING_TAX_REFUNDED,
        so.order_increment_id                       as ID,
        so.order_id                                 as ORDER_ID,
        so.customer_email                           as CUSTOMER_EMAIL,
        convert_timezone(
            'UTC',
            '{{ var("ammodepot_timezone") }}',
            cast(so.created_at as timestamp)
        )                                           as CREATED_AT,
        so.customer_firstname
        || ' '
        || so.customer_lastname                     as CUSTOMER_NAME,
        so.shipping_address_id                      as BILLING_ADDRESS,
        so.shipping_method                          as SHIPPING_INFORMATION,
        so.store_id                                 as STORE_ID,
        so.shipping_description                     as SHIPPING_DESCRIPTION,
        sg.shipment_status_code                     as SHIPMENT_STATUS,
        sg.shipping_address_text                    as SHIPPING_ADDRESS,
        sg.shipping_name                            as SHIPPING_NAME,
        so.order_status                             as STATUS,
        sg.shipping_information                     as SHIPPING_INFORMATION2,
        c.method                                    as METHOD,
        c.carrier_title                             as CARRIER_TITLE,
        addr.postcode                               as POSTCODE,
        addr.country_code                           as COUNTRY,
        addr.region                                 as REGION,
        addr.city                                   as CITY,
        addr.phone_number                           as TELEPHONE,
        fi.freightamount                            as FREIGHTAMOUNT,
        fi.net_amount                               as NET_AMOUNT,
        fi.packagenumb                              as PACKAGENUMB,
        fi.freightweight                            as FREIGHTWEIGHT,
        q.ext_shipping_info                         as EXT_SHIPPING_INFO,
        case when so.base_subtotal >= {{ var('ammodepot_free_shipping_threshold') }} then 'Yes' else 'No' end
                                                   as ISFREE,
        fi.carrierserviceid                         as CARRIERSERVICEID,
        case when fo.quote_id is not null then 'Yes' else 'No' end
                                                   as ISFREEAUTO
    from {{ ref('magento_sales_order') }}               as so
    left join {{ ref('magento_sales_shipment_grid') }}  as sg
      on cast(so.order_id           as varchar) = cast(sg.order_id           as varchar)
    left join codes                                   as c
      on cast(so.shipping_method     as varchar) = cast(c.code                 as varchar)
    left join address                                as addr
      on cast(so.shipping_address_id as varchar) = cast(addr.order_address_id as varchar)
    left join freightinfo                            as fi
      on cast(so.order_id           as varchar) = cast(fi.order_magento       as varchar)
    left join {{ ref('magento_quote') }}              as q
      on cast(so.quote_id            as varchar) = cast(q.entity_id            as varchar)
    left join freeoptions                             as fo
      on so.quote_id = fo.quote_id
)

select
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
    svc.idcarrier   as IDCARRIER,
    svc.carrierservice as CARRIERSERVICE
from f_ship as fs
left join service as svc
  on cast(fs.CARRIERSERVICEID   as varchar) = cast(svc.idcarrier      as varchar)
