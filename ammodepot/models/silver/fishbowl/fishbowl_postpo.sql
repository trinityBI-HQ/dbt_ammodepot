with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        poid,
        exttxnid,
        postdate,
        statusid,
        dateposted,
        exttxnhash,
        datecreated,
        extrefnumber,
        exttxnnumber,
        journaltxnid,
        journalposted,
        datelastmodified,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'postpo') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as post_po_id,               -- Renamed primary key for this PO posting record
    poid as purchase_order_id,      -- Foreign key to the Purchase Order (PO) table

    -- Posting Details
    statusid as post_status_id,     -- Status of this PO posting
    postdate as post_date,          -- Date the PO posting event occurred (may differ from dateposted)

    -- External Accounting System Integration (e.g., QuickBooks)
    exttxnid as external_transaction_id,
    exttxnhash as external_transaction_hash,
    extrefnumber as external_reference_number,
    exttxnnumber as external_transaction_number,

    -- Journal Entry Details (if applicable)
    journaltxnid as journal_transaction_id,
    CAST(journalposted as BOOLEAN) as is_journal_posted, -- Assuming this is a flag

    -- Timestamps
    dateposted as posted_to_accounting_at, -- Date the transaction was actually posted to accounting
    datecreated as record_created_at,
    datelastmodified as last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
