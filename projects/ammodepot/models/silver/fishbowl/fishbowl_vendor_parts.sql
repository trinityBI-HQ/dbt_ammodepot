with source_data as (

    select
        partid,
        datelastmodified,
        lastcost
    from {{ source('fishbowl', 'vendorparts') }}
    where _ab_cdc_deleted_at is null

)

select
    partid,
    datelastmodified,
    lastcost
from source_data
