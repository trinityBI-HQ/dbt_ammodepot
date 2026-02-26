with source_data as (

    select
        entity_id,
        product_id,
        category_id
    from {{ source('magento', 'catalog_category_product') }}

)

select
    entity_id,
    product_id,
    category_id
from source_data
