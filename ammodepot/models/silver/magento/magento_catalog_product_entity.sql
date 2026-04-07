with source_data as (
    select
        entity_id,
        attribute_set_id,
        type_id,
        sku,
        has_options,
        required_options,
        created_at,
        updated_at
    from
        {{ source('magento', 'catalog_product_entity') }}
    where
        _ab_cdc_deleted_at is null
        {# Drop rows with NULL primary key. The Iceberg append-only landing
           preserves malformed CDC events (seen as an 11-row burst on
           2026-04-01 20:46 UTC) that the legacy Snowflake MERGE destination
           was silently filtering out. Without this guard, ROW_NUMBER
           collapses all NULL-PK rows into one row which propagates to
           d_product and fails not_null tests. #}
        and entity_id is not null
    qualify
        row_number() over (
            partition by entity_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    entity_id as product_entity_id,
    attribute_set_id,
    type_id,
    sku,
    cast(has_options as boolean) as has_options,
    cast(required_options as boolean) as required_options,
    created_at,
    updated_at
from
    source_data
