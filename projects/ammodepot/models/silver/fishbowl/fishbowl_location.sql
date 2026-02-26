{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (
    -- This CTE selects all relevant columns from the source
    select
        id,
        name,
        typeid,
        parentid,
        pickable,
        sortorder,
        activeflag,
        receivable,
        defaultflag,
        description,
        customfields,
        defaultvendorid,
        locationgroupid,
        datelastmodified,
        defaultcustomerid,
        countedasavailable,

        -- Airbyte CDC columns for filtering/metadata
        _ab_cdc_cursor,
        _ab_cdc_log_pos,
        _ab_cdc_log_file,
        _ab_cdc_deleted_at,
        _ab_cdc_updated_at

        -- Columns to be excluded from final select:
        -- _airbyte_raw_id, _airbyte_extracted_at, _airbyte_generation_id, _airbyte_meta
    from
        {{ source('fishbowl', 'location') }}
    where
        -- Filter out soft deletes. Assuming _ab_cdc_deleted_at follows previous patterns (VARCHAR).
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as location_id,              -- Renamed primary key
    parentid as parent_location_id, -- Foreign key for hierarchical locations
    locationgroupid as location_group_id, -- Foreign key to locationgroup

    -- Location Details
    name as location_name,
    description as location_description,
    typeid as location_type_id,
    sortorder as sort_order,

    -- Flags
    CAST(activeflag as BOOLEAN) as is_active,
    CAST(defaultflag as BOOLEAN) as is_default_location,
    CAST(pickable as BOOLEAN) as is_pickable,
    CAST(receivable as BOOLEAN) as is_receivable,
    CAST(countedasavailable as BOOLEAN) as is_counted_as_available, -- Assuming this is a boolean flag

    -- Defaults
    defaultvendorid as default_vendor_id,
    defaultcustomerid as default_customer_id,

    -- Custom Fields
    customfields as custom_fields,  -- Typically JSON or serialized string

    -- Timestamps
    datelastmodified as last_modified_at,

    -- Airbyte CDC Metadata (kept as requested, adjust if not needed in final silver)
    _ab_cdc_cursor,
    _ab_cdc_log_pos,
    _ab_cdc_log_file,
    _ab_cdc_updated_at

from
    source_data
