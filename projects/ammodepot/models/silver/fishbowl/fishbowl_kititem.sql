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
        note,
        uomid,
        maxqty,
        minqty,
        kittypeid,
        productid,
        sortorder,
        taxrateid,
        defaultqty,
        discountid,
        datecreated,
        description,
        kitproductid,
        soitemtypeid,
        kititemtypeid,
        datelastmodified,
        qtypriceadjustment,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    FROM
        {{ source('fishbowl', 'kititem') }}
    WHERE
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS kit_item_id,              -- Renamed primary key for this kit item record
    kitproductid AS kit_product_id, -- Foreign key to the parent/main kit product
    productid AS component_product_id, -- Foreign key to the component product within the kit

    -- Kit Item Configuration
    kittypeid AS kit_type_id,       -- Type of kit this item belongs to
    kititemtypeid AS kit_item_type_id, -- Type of this specific item within the kit
    soitemtypeid AS default_so_item_type_id, -- Default SO item type when this kit item is added to an SO

    -- Quantity & UOM
    defaultqty AS default_quantity,
    minqty AS minimum_quantity,
    maxqty AS maximum_quantity,
    uomid AS uom_id,                -- Unit of Measure for this kit item

    -- Pricing & Tax
    discountid AS discount_id,      -- Discount applied to this kit item
    taxrateid AS tax_rate_id,        -- Tax rate for this kit item
    qtypriceadjustment AS quantity_price_adjustment, -- Adjustment based on quantity

    -- Display & Other
    description AS kit_item_description,
    note AS kit_item_note,
    sortorder AS sort_order,

    -- Timestamps
    datecreated AS created_at,
    datelastmodified AS last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

FROM
    source_data