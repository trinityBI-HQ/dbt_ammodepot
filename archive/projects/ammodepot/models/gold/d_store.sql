select
    ms.store_code       as CODE,
    ms.store_name       as NAME,
    ms.group_id   as GROUP_ID,
    ms.store_id   as STORE_ID,
    ms.is_active  as IS_ACTIVE,
    ms.sort_order as SORT_ORDER,
    ms.website_id as WEBSITE_ID
from {{ ref('magento_store') }} as ms
