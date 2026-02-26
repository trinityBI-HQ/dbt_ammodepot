with source_data as (

    select
        product_id,
        parent_id
    from {{ source('magento', 'catalog_product_super_link') }}

)

select
    product_id,
    parent_id
from source_data
