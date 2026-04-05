with source_data as (

    select
        id,
        partid,
        datelastmodified,
        lastcost
    from {{ source('fishbowl', 'vendorparts') }}
    where _ab_cdc_deleted_at is null

)

select
    id,
    partid,
    datelastmodified,
    lastcost
from source_data
