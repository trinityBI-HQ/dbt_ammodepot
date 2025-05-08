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
    FROM
        {{ source('fishbowl', 'postpo') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS post_po_id,               -- Renamed primary key for this PO posting record
    poid AS purchase_order_id,      -- Foreign key to the Purchase Order (PO) table

    -- Posting Details
    statusid AS post_status_id,     -- Status of this PO posting
    postdate AS post_date,          -- Date the PO posting event occurred (may differ from dateposted)

    -- External Accounting System Integration (e.g., QuickBooks)
    exttxnid AS external_transaction_id,
    exttxnhash AS external_transaction_hash,
    extrefnumber AS external_reference_number,
    exttxnnumber AS external_transaction_number,

    -- Journal Entry Details (if applicable)
    journaltxnid AS journal_transaction_id,
    CAST(journalposted AS BOOLEAN) AS is_journal_posted, -- Assuming this is a flag

    -- Timestamps
    dateposted AS posted_to_accounting_at, -- Date the transaction was actually posted to accounting
    datecreated AS record_created_at,
    datelastmodified AS last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data