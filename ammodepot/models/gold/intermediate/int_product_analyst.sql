select
    "Product ID"        as PRODUCT_ID,
    SKU,
    "Product Name"      as PRODUCT_NAME,
    "Caliber"           as CALIBER,
    "Manufacturer SKU"  as MANUFACTURER,
    "Projectile"        as PROJECTILE,
    "Vendor"            as PRODUCT_VENDOR,
    USE_TYPE_CATEGORY,
    "Primary Category"  as PRIMARY_CATEGORY,
    "Discontinued"      as DISCONTINUED,
    "Unit Type"         as UNIT_TYPE,
    AVGCOST,
    LASTVENDORCOST,
    "General Purpose"   as GENERAL_PURPOSE
from {{ ref('d_product') }}
