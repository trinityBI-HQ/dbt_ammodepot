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
            order by coalesce(try_cast(_ab_cdc_updated_at as timestamp), epoch_ms(_airbyte_extracted_at)) desc nulls last
        ) = 1

)

select
    id,
    partid,
    datelastmodified,
    lastcost
from source_data
