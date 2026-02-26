select * 
from {{ source('magento','catalog_product_super_link') }}
