{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Identifiers
        id,
        recordid,         -- Foreign key to another view's record
        groupid,
        channelid,        -- Context specific ID

        -- Core Info
        plugin,
        info,
        viewname,        -- Name of the view recordid belongs to

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.PLUGININFO
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'plugininfo') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Identifiers
    id AS plugin_info_id,        -- Renamed primary key
    recordid AS record_id,            -- Renamed foreign key
    groupid AS group_id,              -- Renamed foreign key/grouping ID
    channelid AS channel_id,          -- Renamed, context-specific ID

    -- Core Info
    plugin AS plugin_name,         -- Renamed for clarity
    info AS plugin_info_data,    -- Renamed for clarity
    viewname AS related_view_name -- Renamed for clarity

FROM
    source_data