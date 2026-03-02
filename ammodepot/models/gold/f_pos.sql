with po_item_details as (
    select
        poi.po_item_id,
        poi.unit_cost,
        poi.total_cost,
        poi.last_fulfillment_date,
        poi.scheduled_fulfillment_date,
        poi.quantity_fulfilled,
        poi.quantity_ordered,
        po.vendor_id,
        po.created_at as po_created_at,
        po.confirmed_at as po_confirmed_at,
        po.issued_at as po_issued_at,
        po.first_ship_date as po_first_shipment_date,
        poi.purchase_order_id
    from
        {{ ref('fishbowl_poitem') }} as poi
    left join
        {{ ref('fishbowl_po') }} as po
        on poi.purchase_order_id = po.purchase_order_id
),

receipt_item_base as (
    select
        p.part_id,
        ri.receipt_item_id as idid,
        r.location_group_id,
        ri.reconciled_at as datereconciled,
        p.part_number as num,
        ri.received_at as datereceived,
        ri.last_modified_at as datelastmodified,
        ob.unit_cost,
        ob.total_cost,
        ob.last_fulfillment_date,
        ob.scheduled_fulfillment_date,
        ob.quantity_fulfilled as qtyfulfilled,
        ob.quantity_ordered as qtytofulfill,
        ob.vendor_id,
        ob.po_created_at as datecreated,
        ob.po_confirmed_at as dateconfirmed,
        ob.po_issued_at as dateissued,
        ob.po_first_shipment_date as datefirstship,
        ob.purchase_order_id as poid,
        ri.receipt_item_status_id as statusid,
        ri.po_item_id,
        coalesce(
            case
                when (ri.uom_id <> p.default_uom_id) and (uomc.uom_conversion_id is not null)
                then (ri.quantity_received * uomc.multiply_factor) / case when uomc.factor = 0 then 1 else uomc.factor end
                else ri.quantity_received
            end,
            0
        ) as quantity_received_converted,
        coalesce(
            lag(ri.received_at) over (partition by ri.po_item_id order by ri.received_at asc),
            ob.po_created_at
        ) as last_date_prior_to_received
    from
        {{ ref('fishbowl_receiptitem') }} as ri
    left join
        {{ ref('fishbowl_receipt') }} as r
        on r.receipt_id = ri.receipt_id
    left join
        po_item_details as ob
        on ri.po_item_id = ob.po_item_id
    left join
        {{ ref('fishbowl_part') }} as p
        on p.part_id = ri.part_id
    left join
        {{ ref('fishbowl_uomconversion') }} as uomc
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = ri.uom_id
    where
        r.order_type_id = {{ var('ammodepot_receipt_order_type_id') }}
        and ri.receipt_item_status_id in ({{ var('ammodepot_receipt_status_received') }}, {{ var('ammodepot_receipt_status_reconciled') }})
),

ranked_lead_times_vendor_part as (
    select
        poid,
        vendor_id,
        num as part_number,
        datereceived,
        last_date_prior_to_received,
        datediff(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            vendor_id,
            num,
            datereceived,
            last_date_prior_to_received,
            row_number() over (
                partition by vendor_id, num
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

ranked_lead_times_vendor as (
    select
        poid,
        vendor_id,
        datereceived,
        last_date_prior_to_received,
        datediff(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            vendor_id,
            datereceived,
            last_date_prior_to_received,
            row_number() over (
                partition by vendor_id
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

ranked_lead_times_part as (
    select
        poid,
        num as part_number,
        datereceived,
        last_date_prior_to_received,
        datediff(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            num,
            datereceived,
            last_date_prior_to_received,
            row_number() over (
                partition by num
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

avg_lead_time_vendor_part as (
    select
        cast(vendor_id as varchar) || '@' || part_number as key_main,
        ceil(avg(date_difference)) as avg_lead_time
    from
        ranked_lead_times_vendor_part
    group by
        vendor_id,
        part_number
),

avg_lead_time_vendor as (
    select
        cast(vendor_id as varchar) as key_main,
        ceil(avg(date_difference)) as avg_lead_time
    from
        ranked_lead_times_vendor
    group by
        vendor_id
),

avg_lead_time_part as (
    select
        part_number as key_main,
        ceil(avg(date_difference)) as avg_lead_time
    from
        ranked_lead_times_part
    group by
        part_number
)

select
    fp.part_id,
    fp.idid as receipt_item_id,
    fp.location_group_id,
    fp.quantity_received_converted as qty,
    fp.datereconciled,
    fp.num as part_number,
    fp.datereceived,
    fp.datelastmodified,
    fp.unit_cost,
    fp.total_cost,
    fp.last_fulfillment_date,
    fp.scheduled_fulfillment_date,
    fp.qtyfulfilled as quantity_fulfilled,
    fp.qtytofulfill as quantity_to_fulfill,
    fp.vendor_id,
    fp.datecreated as po_created_at,
    fp.dateconfirmed as po_confirmed_at,
    fp.dateissued as po_issued_at,
    fp.datefirstship as po_first_shipment_date,
    fp.poid as purchase_order_id,
    fp.statusid as receipt_item_status_id,
    fp.po_item_id,
    fp.last_date_prior_to_received,
    lv.avg_lead_time as vendor_lead_time,
    l.avg_lead_time as vendor_product_leadtime,
    lnum.avg_lead_time as product_leadtime,
    coalesce(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time) as precise_leadtime,
    dateadd(day, cast(coalesce(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time) as int), fp.last_date_prior_to_received) as date_expected
from
    receipt_item_base as fp
left join
    avg_lead_time_vendor_part as l
    on cast(fp.vendor_id as varchar) || '@' || fp.num = l.key_main
left join
    avg_lead_time_vendor as lv
    on cast(fp.vendor_id as varchar) = lv.key_main
left join
    avg_lead_time_part as lnum
    on fp.num = lnum.key_main
