with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'postpoitem') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by id
            order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
        ) = 1
)

select
    -- Identifiers
    id as post_po_item_id,          -- Renamed primary key for this PO item posting record
    postpoid as post_po_id,         -- Foreign key to the POSTPO table
    poitemid as po_item_id,         -- Foreign key to the POITEM table (original PO line item)
    receiptitemid as receipt_item_id,-- Foreign key to the RECEIPTITEM table (if applicable)
    shipitemid as ship_item_id,     -- Foreign key to the SHIPITEM table (if related to a shipment)

    -- Quantity & Cost
    qty as quantity_posted,
    stdcost as standard_cost_at_posting,
    postedtotalcost as posted_total_cost,
    mcpostedtotalcost as mc_posted_total_cost, -- Multi-currency posted total cost
    receivedtotalcost as received_total_cost, -- Cost from the receipt

    -- External Accounting System Integration (e.g., QuickBooks)
    exttxnid as external_transaction_id,
    exttxnhash as external_transaction_hash,
    extrefnumber as external_reference_number,
    exttxnlineid as external_transaction_line_id,

    -- Timestamps
    datecreated as record_created_at,
    datelastmodified as last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
