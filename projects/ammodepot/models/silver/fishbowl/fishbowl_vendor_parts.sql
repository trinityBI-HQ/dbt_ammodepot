with source_data as (

    select
        partid        as part_id,
        datelastmodified as date_last_modified,
        lastcost      as last_cost
    from {{ source('fishbowl', 'vendorparts') }}
    where _ab_cdc_deleted_at is null

)

select
    part_id,
    date_last_modified,
    last_cost
from source_data
