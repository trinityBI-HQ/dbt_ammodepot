{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Core Identifiers & Cost Info
        id,
        qty,
        partid,
        avgcost,
        totalcost,

        -- Timestamps
        datecreated,
        datelastmodified,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded: Airbyte metadata, other CDC columns

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.PARTCOST
        -- Assuming you have a dbt source named 'fishbowl' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        -- Adjust 'fishbowl' if your source name is different (e.g., 'ad_airbyte')
        {{ source('fishbowl', 'partcost') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS part_cost_id,     -- Renamed primary key for this cost record
    partid AS part_id,      -- Renamed foreign key to the PART view

    -- Cost & Quantity Info
    avgcost AS average_cost,-- Renamed for clarity
    totalcost AS total_cost,-- Renamed for clarity
    qty AS quantity,        -- Renamed for clarity

    -- Timestamps
    datecreated AS created_at, -- Standardized timestamp name
    datelastmodified AS last_modified_at -- Standardized timestamp name

FROM
    source_data
