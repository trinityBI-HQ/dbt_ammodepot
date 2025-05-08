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
        qty,
        stdcost,
        exttxnid,
        poitemid,
        postpoid,
        exttxnhash,
        shipitemid,
        datecreated,
        extrefnumber,
        exttxnlineid,
        receiptitemid,
        postedtotalcost,
        datelastmodified,
        mcpostedtotalcost,
        receivedtotalcost,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'postpoitem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS post_po_item_id,          -- Renamed primary key for this PO item posting record
    postpoid AS post_po_id,         -- Foreign key to the POSTPO table
    poitemid AS po_item_id,         -- Foreign key to the POITEM table (original PO line item)
    receiptitemid AS receipt_item_id,-- Foreign key to the RECEIPTITEM table (if applicable)
    shipitemid AS ship_item_id,     -- Foreign key to the SHIPITEM table (if related to a shipment)

    -- Quantity & Cost
    qty AS quantity_posted,
    stdcost AS standard_cost_at_posting,
    postedtotalcost AS posted_total_cost,
    mcpostedtotalcost AS mc_posted_total_cost, -- Multi-currency posted total cost
    receivedtotalcost AS received_total_cost, -- Cost from the receipt

    -- External Accounting System Integration (e.g., QuickBooks)
    exttxnid AS external_transaction_id,
    exttxnhash AS external_transaction_hash,
    extrefnumber AS external_reference_number,
    exttxnlineid AS external_transaction_line_id,

    -- Timestamps
    datecreated AS record_created_at,
    datelastmodified AS last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data