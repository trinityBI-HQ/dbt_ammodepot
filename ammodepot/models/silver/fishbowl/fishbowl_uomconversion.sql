with source_data as (

    select
        -- Core Identifiers & Conversion Info
        id,
        factor,
        touomid,
        multiply,
        fromuomid,
        description,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded: Airbyte metadata, other CDC columns

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION
        -- Assuming you have a dbt source named 'fishbowl' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        -- Adjust 'fishbowl' if your source name is different (e.g., 'ad_airbyte')
        {{ source('fishbowl', 'uomconversion') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
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
    id as uom_conversion_id,    -- Renamed primary key
    fromuomid as from_uom_id,   -- Renamed foreign key
    touomid as to_uom_id,       -- Renamed foreign key

    -- Conversion Factors
    multiply as multiply_factor,-- Renamed for clarity (this is usually the primary factor)
    factor as factor,           -- Keeping factor (often 1/multiply_factor, good to have both)

    -- Description
    description as conversion_description -- Renamed for clarity

from
    source_data
