{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (
    -- This CTE selects all relevant columns from the source
    SELECT
        id,
        refid,
        txnid,
        amount,
        typeid,
        orderid,
        quantity,
        statusid,
        refitemid,
        refnumber,
        serialnum,
        txnlineid,
        customerid,
        dateposted,
        datecreated,
        ordertypeid,
        editsequence,
        postedtotalcost,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'post') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS post_id,                  -- Renamed primary key for this posting record
    txnid AS transaction_id,        -- Accounting transaction ID
    txnlineid AS transaction_line_id, -- Line ID within the accounting transaction
    orderid AS order_id,            -- Related order ID (SO, PO, etc.)
    ordertypeid AS order_type_id,    -- Type of the related order
    refid AS reference_id,          -- General reference ID (context-dependent)
    refitemid AS reference_item_id,  -- Item ID within the reference document
    customerid AS customer_id,      -- Related customer ID

    -- Posting Details
    typeid AS post_type_id,         -- Type of posting (e.g., inventory, AR, AP)
    statusid AS post_status_id,     -- Status of the posting
    refnumber AS reference_number,   -- Reference document number
    serialnum AS serial_number,     -- Serial number if applicable

    -- Financials & Quantity
    amount AS post_amount,
    postedtotalcost AS posted_total_cost,
    quantity AS posted_quantity,

    -- Timestamps & Sequencing
    dateposted AS posted_at,
    datecreated AS record_created_at,
    editsequence AS edit_sequence,  -- For QuickBooks integration, sequence of edits

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data