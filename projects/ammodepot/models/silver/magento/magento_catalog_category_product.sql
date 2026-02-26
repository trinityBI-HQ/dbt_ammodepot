with source_data as (

    select
        product_id,
        category_id
    from {{ source('magento', 'catalog_category_product') }}

)

select
    product_id,
    category_id
from source_data
