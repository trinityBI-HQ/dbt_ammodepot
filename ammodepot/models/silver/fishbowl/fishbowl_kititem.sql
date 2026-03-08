with source_data as (
    -- This CTE selects all relevant columns from the source
    select
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
    from
        {{ source('fishbowl', 'kititem') }}
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
    id as kit_item_id,              -- Renamed primary key for this kit item record
    kitproductid as kit_product_id, -- Foreign key to the parent/main kit product
    productid as component_product_id, -- Foreign key to the component product within the kit

    -- Kit Item Configuration
    kittypeid as kit_type_id,       -- Type of kit this item belongs to
    kititemtypeid as kit_item_type_id, -- Type of this specific item within the kit
    soitemtypeid as default_so_item_type_id, -- Default SO item type when this kit item is added to an SO

    -- Quantity & UOM
    defaultqty as default_quantity,
    minqty as minimum_quantity,
    maxqty as maximum_quantity,
    uomid as uom_id,                -- Unit of Measure for this kit item

    -- Pricing & Tax
    discountid as discount_id,      -- Discount applied to this kit item
    taxrateid as tax_rate_id,        -- Tax rate for this kit item
    qtypriceadjustment as quantity_price_adjustment, -- Adjustment based on quantity

    -- Display & Other
    description as kit_item_description,
    note as kit_item_note,
    sortorder as sort_order,

    -- Timestamps
    datecreated as created_at,
    datelastmodified as last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
