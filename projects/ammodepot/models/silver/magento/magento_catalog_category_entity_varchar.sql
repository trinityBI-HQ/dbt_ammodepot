select *
from {{ source('magento','catalog_category_entity_varchar') }}
