{{
  config(
    materialized = 'table',
    schema = 'silver' 
  )
}}

WITH source_data AS (

    SELECT
        -- Core Identifiers & Relationship Info
        id,
        note,
        typeid,
        tableid1,
        tableid2,
        recordid1,
        recordid2,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded: Airbyte metadata, other CDC columns

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.OBJECTTOOBJECT
        -- Assuming you have a dbt source named 'fishbowl' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        -- Adjust 'fishbowl' if your source name is different (e.g., 'ad_airbyte')
        {{ source('fishbowl', 'objecttoobject') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS object_relationship_id,    -- Renamed primary key of the relationship itself
    typeid AS relationship_type_id,  -- ID describing the type of relationship

    -- Related Object 1 Info
    tableid1 AS object1_table_id,    -- ID of the table for the first object
    recordid1 AS object1_record_id,  -- Record ID of the first object (in tableid1)

    -- Related Object 2 Info
    tableid2 AS object2_table_id,    -- ID of the table for the second object
    recordid2 AS object2_record_id,  -- Record ID of the second object (in tableid2)

    -- Description
    note AS relationship_note        -- Note describing the relationship

FROM
    source_data