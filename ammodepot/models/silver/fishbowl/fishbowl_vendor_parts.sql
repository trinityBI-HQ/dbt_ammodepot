with source_data as (

    select
        id,
        partid,
        datelastmodified,
        lastcost
    from {{ source('fishbowl', 'vendorparts') }}
    where _ab_cdc_deleted_at is null
    qualify
        row_number() over (
            partition by id
            order by coalesce(try_to_timestamp(_ab_cdc_updated_at), to_timestamp(_airbyte_extracted_at, 3)) desc nulls last
        ) = 1

)

select
    id,
    partid,
    datelastmodified,
    lastcost
from source_data
