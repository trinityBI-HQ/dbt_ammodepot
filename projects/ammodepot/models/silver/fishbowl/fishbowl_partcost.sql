{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

with source_data as (

    select
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

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.PARTCOST
        -- Assuming you have a dbt source named 'fishbowl' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        -- Adjust 'fishbowl' if your source name is different (e.g., 'ad_airbyte')
        {{ source('fishbowl', 'partcost') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as part_cost_id,     -- Renamed primary key for this cost record
    partid as part_id,      -- Renamed foreign key to the PART view

    -- Cost & Quantity Info
    avgcost as average_cost,-- Renamed for clarity
    totalcost as total_cost,-- Renamed for clarity
    qty as quantity,        -- Renamed for clarity

    -- Timestamps
    datecreated as created_at, -- Standardized timestamp name
    datelastmodified as last_modified_at -- Standardized timestamp name

from
    source_data
