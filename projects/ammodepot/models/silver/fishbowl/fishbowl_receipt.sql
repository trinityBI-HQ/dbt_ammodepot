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
        soid,
        xoid,
        typeid,
        userid,
        statusid,
        ordertypeid,
        locationgroupid,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'receipt') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS receipt_id,               -- Renamed primary key for this receipt record
    poid AS purchase_order_id,      -- Foreign key to Purchase Order (if applicable)
    soid AS sales_order_id,         -- Foreign key to Sales Order (if applicable, e.g., RMA)
    xoid AS transfer_order_id,      -- Foreign key to Transfer Order (if applicable)
    ordertypeid AS order_type_id,    -- Type of order this receipt is associated with

    -- Receipt Details
    typeid AS receipt_type_id,      -- Type of receipt (e.g., PO receipt, RMA receipt)
    statusid AS receipt_status_id,  -- Status of the receipt
    userid AS user_id,              -- User who created/processed the receipt
    locationgroupid AS location_group_id, -- Location group where items were received

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data