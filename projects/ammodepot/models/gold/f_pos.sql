{{
  config(
    materialized = 'table',
    schema       = 'gold'
  )
}}

-- CTE to get relevant PO Item details needed later
WITH po_item_details AS (
    SELECT
        poi.po_item_id,                  -- from fishbowl_poitem
        poi.unit_cost,                   -- from fishbowl_poitem
        poi.total_cost,                  -- from fishbowl_poitem
        poi.last_fulfillment_date,       -- from fishbowl_poitem
        poi.scheduled_fulfillment_date,  -- from fishbowl_poitem
        poi.quantity_fulfilled,          -- from fishbowl_poitem
        poi.quantity_ordered,         -- Corrected from qtytofulfill based on your previous edit
        po.vendor_id,                    -- from fishbowl_po
        po.created_at AS po_created_at,  -- from fishbowl_po
        po.confirmed_at AS po_confirmed_at, -- from fishbowl_po
        po.issued_at AS po_issued_at,      -- from fishbowl_po
        po.first_ship_date AS po_first_shipment_date, -- from fishbowl_po
        poi.purchase_order_id            -- from fishbowl_poitem
    FROM
        {{ ref('fishbowl_poitem') }} poi
    LEFT JOIN
        {{ ref('fishbowl_po') }} po
        ON poi.purchase_order_id = po.purchase_order_id -- Use silver renamed columns
),

-- Base query joining receipt items with PO details and calculating UOM converted quantity
receipt_item_base AS (
    SELECT
        p.part_id,                          -- from fishbowl_part
        ri.receipt_item_id AS idid,         -- from fishbowl_receiptitem
        r.location_group_id,                -- from fishbowl_receipt
        ri.reconciled_at AS datereconciled, -- from fishbowl_receiptitem
        p.part_number AS num,               -- from fishbowl_part
        ri.received_at AS datereceived,     -- from fishbowl_receiptitem
        ri.last_modified_at AS datelastmodified, -- from fishbowl_receiptitem
        ob.unit_cost,                       -- from po_item_details
        ob.total_cost,                      -- from po_item_details
        ob.last_fulfillment_date,           -- from po_item_details
        ob.scheduled_fulfillment_date,      -- from po_item_details
        ob.quantity_fulfilled AS qtyfulfilled, -- from po_item_details
        ob.quantity_ordered AS qtytofulfill, -- Corrected from previous edit
        ob.vendor_id,                       -- from po_item_details
        ob.po_created_at AS datecreated,    -- from po_item_details
        ob.po_confirmed_at AS dateconfirmed,-- from po_item_details
        ob.po_issued_at AS dateissued,      -- from po_item_details
        ob.po_first_shipment_date AS datefirstship, -- from po_item_details
        ob.purchase_order_id AS poid,       -- from po_item_details
        ri.receipt_item_status_id AS statusid, -- from fishbowl_receiptitem
        ri.po_item_id,                      -- from fishbowl_receiptitem
        -- Calculate quantity received, converting UOM if necessary
        COALESCE(
            CASE
                -- Corrected comparison to p.default_uom_id based on your previous edit
                WHEN (ri.uom_id <> p.default_uom_id) AND (uomc.uom_conversion_id IS NOT NULL)
                THEN (ri.quantity_received * uomc.multiply_factor) / CASE WHEN uomc.factor = 0 THEN 1 ELSE uomc.factor END -- Avoid Div/0
                ELSE ri.quantity_received
            END,
            0
        ) AS quantity_received_converted,
        -- Use LAG to get prior receipt date; fall back to PO created date if no prior receipt for this PO item
        COALESCE(
            LAG(ri.received_at) OVER (PARTITION BY ri.po_item_id ORDER BY ri.received_at ASC),
            ob.po_created_at -- Fallback to PO creation date
        ) AS last_date_prior_to_received
    FROM
        {{ ref('fishbowl_receiptitem') }} ri
    LEFT JOIN
        {{ ref('fishbowl_receipt') }} r
        ON r.receipt_id = ri.receipt_id
    LEFT JOIN
        po_item_details ob
        ON ri.po_item_id = ob.po_item_id
    LEFT JOIN
        {{ ref('fishbowl_part') }} p
        ON p.part_id = ri.part_id
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uomc
        -- Corrected join condition based on your previous edit
        ON uomc.to_uom_id = p.default_uom_id AND uomc.from_uom_id = ri.uom_id
    WHERE
        r.order_type_id = 10
        AND ri.receipt_item_status_id IN (10, 40) -- Status IDs for received/reconciled?
),

-- Rank receipts for lead time calculation (Vendor + Part)
ranked_lead_times_vendor_part AS (
    SELECT
        poid,
        vendor_id,
        num AS part_number,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) AS date_difference
    FROM (
        SELECT
            poid,
            vendor_id,
            num,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() OVER (
                PARTITION BY vendor_id, num
                ORDER BY datereceived DESC
            ) AS rn
        FROM receipt_item_base
        WHERE datereceived IS NOT NULL AND last_date_prior_to_received IS NOT NULL
    ) AS sub
    WHERE rn <= 3
),

-- Rank receipts for lead time calculation (Vendor Only)
ranked_lead_times_vendor AS (
    SELECT
        poid,
        vendor_id,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) AS date_difference
    FROM (
        SELECT
            poid,
            vendor_id,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() OVER (
                PARTITION BY vendor_id
                ORDER BY datereceived DESC
            ) AS rn
        FROM receipt_item_base
        WHERE datereceived IS NOT NULL AND last_date_prior_to_received IS NOT NULL
    ) AS sub
    WHERE rn <= 3
),

-- Rank receipts for lead time calculation (Part Only)
ranked_lead_times_part AS (
    SELECT
        poid,
        num AS part_number,
        datereceived,
        last_date_prior_to_received,
        DATEDIFF(day, last_date_prior_to_received, datereceived) AS date_difference
    FROM (
        SELECT
            poid,
            num,
            datereceived,
            last_date_prior_to_received,
            ROW_NUMBER() OVER (
                PARTITION BY num
                ORDER BY datereceived DESC
            ) AS rn
        FROM receipt_item_base
        WHERE datereceived IS NOT NULL AND last_date_prior_to_received IS NOT NULL
    ) AS sub
    WHERE rn <= 3
),

-- Calculate Average Lead Time (Vendor + Part)
avg_lead_time_vendor_part AS (
    SELECT
        -- Use || operator for concatenation in Redshift
        vendor_id::VARCHAR || '@' || part_number AS key_main,
        CEILING(AVG(date_difference)) AS avg_lead_time -- CEILING is Redshift equivalent of CEIL
    FROM
        ranked_lead_times_vendor_part
    GROUP BY
        vendor_id,
        part_number
),

-- Calculate Average Lead Time (Vendor Only)
avg_lead_time_vendor AS (
    SELECT
        vendor_id::VARCHAR AS key_main, -- Explicit cast for potential join
        CEILING(AVG(date_difference)) AS avg_lead_time
    FROM
        ranked_lead_times_vendor
    GROUP BY
        vendor_id
),

-- Calculate Average Lead Time (Part Only)
avg_lead_time_part AS (
    SELECT
        part_number AS key_main,
        CEILING(AVG(date_difference)) AS avg_lead_time
    FROM
        ranked_lead_times_part
    GROUP BY
        part_number
)

-- Final Selection and Calculation
SELECT
    fp.part_id,
    fp.idid AS receipt_item_id,
    fp.location_group_id,
    fp.quantity_received_converted AS qty,
    fp.datereconciled,
    fp.num AS part_number,
    fp.datereceived,
    fp.datelastmodified,
    fp.unit_cost,
    fp.total_cost,
    fp.last_fulfillment_date,
    fp.scheduled_fulfillment_date,
    fp.qtyfulfilled AS quantity_fulfilled,
    fp.qtytofulfill AS quantity_to_fulfill, -- Kept name from original view column list
    fp.vendor_id,
    fp.datecreated AS po_created_at,
    fp.dateconfirmed AS po_confirmed_at,
    fp.dateissued AS po_issued_at,
    fp.datefirstship AS po_first_shipment_date,
    fp.poid AS purchase_order_id,
    fp.statusid AS receipt_item_status_id,
    fp.po_item_id,
    fp.last_date_prior_to_received,
    lv.avg_lead_time AS vendor_lead_time,
    l.avg_lead_time AS vendor_product_leadtime,
    lnum.avg_lead_time AS product_leadtime,
    COALESCE(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time) AS precise_leadtime,
    -- Redshift DATEADD syntax
    DATEADD(day, COALESCE(l.avg_lead_time, lv.avg_lead_time, lnum.avg_lead_time)::INT, fp.last_date_prior_to_received) AS date_expected
FROM
    receipt_item_base fp
LEFT JOIN
    avg_lead_time_vendor_part l
    -- Use || operator for concatenation in Redshift join condition
    ON fp.vendor_id::VARCHAR || '@' || fp.num = l.key_main
LEFT JOIN
    avg_lead_time_vendor lv
    ON fp.vendor_id::VARCHAR = lv.key_main -- Explicit cast for join
LEFT JOIN
    avg_lead_time_part lnum
    ON fp.num = lnum.key_main