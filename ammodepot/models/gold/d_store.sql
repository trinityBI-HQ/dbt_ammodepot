with stores as (
    select
        ms.store_code       as CODE,
        ms.store_name       as NAME,
        ms.group_id   as GROUP_ID,
        ms.store_id   as STORE_ID,
        ms.is_active  as IS_ACTIVE,
        ms.sort_order as SORT_ORDER,
        ms.website_id as WEBSITE_ID
    from {{ ref('magento_store') }} as ms

    union all

    select
        'admin'   as CODE,
        'Admin'   as NAME,
        0         as GROUP_ID,
        0         as STORE_ID,
        1         as IS_ACTIVE,
        0         as SORT_ORDER,
        0         as WEBSITE_ID
)

select * from stores
