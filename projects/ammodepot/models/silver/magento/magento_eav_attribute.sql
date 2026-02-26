select * 
from {{ source('magento','eav_attribute') }}
