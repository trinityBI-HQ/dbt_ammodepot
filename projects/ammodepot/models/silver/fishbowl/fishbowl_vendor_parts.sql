select *
from {{ source('fishbowl', 'vendorparts') }}
