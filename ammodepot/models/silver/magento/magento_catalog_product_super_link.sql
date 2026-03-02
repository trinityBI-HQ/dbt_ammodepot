with source_data as (

    select
        link_id,
        product_id,
        parent_id
    from {{ source('magento', 'catalog_product_super_link') }}

)

select
    link_id,
    product_id,
    parent_id
from source_data
