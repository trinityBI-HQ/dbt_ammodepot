select * 
from {{ source('magento','catalog_category_product') }}
