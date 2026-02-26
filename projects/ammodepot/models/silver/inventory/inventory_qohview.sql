with tagserialview_cte as (
    select
        l.location_group_id     as location_group_id,
        t.location_id           as location_id,
        t.part_id               as part_id,
        t.tag_number            as tag_number,
        ts.serial_number_value  as serial_number,
        t.quantity_on_tag       as quantity_on_tag
    from        {{ ref('fishbowl_location') }}            as l
    inner join        {{ ref('fishbowl_tag') }}                 as t     on    l.location_id = t.location_id
    left join   {{ ref('fishbowl_tagserialview') }}       as ts    on    ts.tag_id = t.tag_id
)

select
        location_group_id,
        location_id,
        part_id,
        tag_number,
        serial_number,
        ((1 - quantity_on_tag) * (COUNT(serial_number) - 1) + 1) as calculated_quantity_on_hand
    from    tagserialview_cte
    group by
        location_group_id,
        location_id,
        part_id,
        tag_number,
        serial_number,
        quantity_on_tag
