{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
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

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.UOMCONVERSION
        -- Assuming you have a dbt source named 'fishbowl' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        -- Adjust 'fishbowl' if your source name is different (e.g., 'ad_airbyte')
        {{ source('fishbowl', 'uomconversion') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS uom_conversion_id,    -- Renamed primary key
    fromuomid AS from_uom_id,   -- Renamed foreign key
    touomid AS to_uom_id,       -- Renamed foreign key

    -- Conversion Factors
    multiply AS multiply_factor,-- Renamed for clarity (this is usually the primary factor)
    factor AS factor,           -- Keeping factor (often 1/multiply_factor, good to have both)

    -- Description
    description AS conversion_description -- Renamed for clarity

FROM
    source_data