-- CTE to get relevant PO Item details needed later
with po_item_details as (
    select
        poi.po_item_id,                  -- from fishbowl_poitem
        poi.unit_cost,                   -- from fishbowl_poitem
        poi.total_cost,                  -- from fishbowl_poitem
        poi.last_fulfillment_date,       -- from fishbowl_poitem
        poi.scheduled_fulfillment_date,  -- from fishbowl_poitem
        poi.quantity_fulfilled,          -- from fishbowl_poitem
        poi.quantity_ordered,         -- Corrected from qtytofulfill based on your previous edit
        po.vendor_id,                    -- from fishbowl_po
        po.created_at as po_created_at,  -- from fishbowl_po
        po.confirmed_at as po_confirmed_at, -- from fishbowl_po
        po.issued_at as po_issued_at,      -- from fishbowl_po
        po.first_ship_date as po_first_shipment_date, -- from fishbowl_po
        poi.purchase_order_id            -- from fishbowl_poitem
    from
        {{ ref('fishbowl_poitem') }} as poi
    left join
        {{ ref('fishbowl_po') }} as po
        on poi.purchase_order_id = po.purchase_order_id -- Use silver renamed columns
),

-- Base query joining receipt items with PO details and calculating UOM converted quantity
receipt_item_base as (
    select
        p.part_id,                          -- from fishbowl_part
        ri.receipt_item_id as idid,         -- from fishbowl_receiptitem
        r.location_group_id,                -- from fishbowl_receipt
        ri.reconciled_at as datereconciled, -- from fishbowl_receiptitem
        p.part_number as num,               -- from fishbowl_part
        ri.received_at as datereceived,     -- from fishbowl_receiptitem
        ri.last_modified_at as datelastmodified, -- from fishbowl_receiptitem
        ob.unit_cost,                       -- from po_item_details
        ob.total_cost,                      -- from po_item_details
        ob.last_fulfillment_date,           -- from po_item_details
        ob.scheduled_fulfillment_date,      -- from po_item_details
        ob.quantity_fulfilled as qtyfulfilled, -- from po_item_details
        ob.quantity_ordered as qtytofulfill, -- Corrected from previous edit
        ob.vendor_id,                       -- from po_item_details
        ob.po_created_at as datecreated,    -- from po_item_details
        ob.po_confirmed_at as dateconfirmed,-- from po_item_details
        ob.po_issued_at as dateissued,      -- from po_item_details
        ob.po_first_shipment_date as datefirstship, -- from po_item_details
        ob.purchase_order_id as poid,       -- from po_item_details
        ri.receipt_item_status_id as statusid, -- from fishbowl_receiptitem
        ri.po_item_id,                      -- from fishbowl_receiptitem
        -- Calculate quantity received, converting UOM if necessary
        COALESCE(
            case
                -- Corrected comparison to p.default_uom_id based on your previous edit
                when (ri.uom_id <> p.default_uom_id) and (uomc.uom_conversion_id is not null)
                then (ri.quantity_received * uomc.multiply_factor) / case when uomc.factor = 0 then 1 else uomc.factor end -- Avoid Div/0
                else ri.quantity_received
            end,
            0
        ) as quantity_received_converted,
        -- Use LAG to get prior receipt date; fall back to PO created date if no prior receipt for this PO item
        COALESCE(
            LAG(ri.received_at) over (partition by ri.po_item_id order by ri.received_at asc),
            ob.po_created_at -- Fallback to PO creation date
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
        -- Corrected join condition based on your previous edit
        on uomc.to_uom_id = p.default_uom_id and uomc.from_uom_id = ri.uom_id
    where
        r.order_type_id = {{ var('ammodepot_receipt_order_type_id') }}
        and ri.receipt_item_status_id in ({{ var('ammodepot_receipt_status_received') }}, {{ var('ammodepot_receipt_status_reconciled') }})
),

-- Rank receipts for lead time calculation (Vendor + Part)
ranked_lead_times_vendor_part as (
    select
        poid,
        vendor_id,
        num as part_number,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            vendor_id,
            num,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() over (
                partition by vendor_id, num
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

-- Rank receipts for lead time calculation (Vendor Only)
ranked_lead_times_vendor as (
    select
        poid,
        vendor_id,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            vendor_id,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() over (
                partition by vendor_id
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

-- Rank receipts for lead time calculation (Part Only)
ranked_lead_times_part as (
    select
        poid,
        num as part_number,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) as date_difference
    from (
        select
            poid,
            num,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() over (
                partition by num
                order by datereceived desc
            ) as rn
        from receipt_item_base
        where datereceived is not null and last_date_prior_to_received is not null
    ) as sub
    where rn <= {{ var('ammodepot_lead_time_rank_limit') }}
),

-- Calculate Average Lead Time (Vendor + Part)
avg_lead_time_vendor_part as (
    select
        -- Use || operator for concatenation in Redshift
        vendor_id::VARCHAR || '@' || part_number as key_main,
        CEILING(AVG(date_difference)) as avg_lead_time -- CEILING is Redshift equivalent of CEIL
    from
        ranked_lead_times_vendor_part
    group by
        vendor_id,
        part_number
),

-- Calculate Average Lead Time (Vendor Only)
avg_lead_time_vendor as (
    select
        vendor_id::VARCHAR as key_main, -- Explicit cast for potential join
        CEILING(AVG(date_difference)) as avg_lead_time
    from
        ranked_lead_times_vendor
    group by
        vendor_id
),

-- Calculate Average Lead Time (Part Only)
avg_lead_time_part as (
    select
        part_number as key_main,
        CEILING(AVG(date_difference)) as avg_lead_time
    from
        ranked_lead_times_part
    group by
        part_number
)

-- Final Selection and Calculation
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
    fp.qtytofulfill as quantity_to_fulfill, -- Kept name from original view column list
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
    COALESCE(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time) as precise_leadtime,
    -- Redshift DATEADD syntax
    DATEADD(day, COALESCE(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time)::INT, fp.last_date_prior_to_received) as date_expected
from
    receipt_item_base as fp
left join
    avg_lead_time_vendor_part as l
    -- Use || operator for concatenation in Redshift join condition
    on fp.vendor_id::VARCHAR || '@' || fp.num = l.key_main
left join
    avg_lead_time_vendor as lv
    on fp.vendor_id::VARCHAR = lv.key_main -- Explicit cast for join
left join
    avg_lead_time_part as lnum
    on fp.num = lnum.key_main
