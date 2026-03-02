with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'post') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as post_id,                  -- Renamed primary key for this posting record
    txnid as transaction_id,        -- Accounting transaction ID
    txnlineid as transaction_line_id, -- Line ID within the accounting transaction
    orderid as order_id,            -- Related order ID (SO, PO, etc.)
    ordertypeid as order_type_id,    -- Type of the related order
    refid as reference_id,          -- General reference ID (context-dependent)
    refitemid as reference_item_id,  -- Item ID within the reference document
    customerid as customer_id,      -- Related customer ID

    -- Posting Details
    typeid as post_type_id,         -- Type of posting (e.g., inventory, AR, AP)
    statusid as post_status_id,     -- Status of the posting
    refnumber as reference_number,   -- Reference document number
    serialnum as serial_number,     -- Serial number if applicable

    -- Financials & Quantity
    amount as post_amount,
    postedtotalcost as posted_total_cost,
    quantity as posted_quantity,

    -- Timestamps & Sequencing
    dateposted as posted_at,
    datecreated as record_created_at,
    editsequence as edit_sequence,  -- For QuickBooks integration, sequence of edits

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
