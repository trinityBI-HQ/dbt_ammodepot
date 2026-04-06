with source_data as (

    select
        store_id,
        name,
        code,
        group_id,
        website_id,
        is_active,
        sort_order,
        _ab_cdc_deleted_at

    from
        {{ source('magento', 'store') }}
    where
        _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by store_id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1
)

select
    store_id as store_id,
    name as store_name,
    code as store_code,
    group_id as group_id,
    website_id as website_id,
    cast(is_active as boolean) as is_active,
    sort_order as sort_order

from
    source_data
