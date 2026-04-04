select
    t.part_id,                         -- from fishbowl_tag
    l.location_group_id,               -- from fishbowl_location
    COALESCE(SUM(t.quantity_on_tag), 0) as quantity_on_hand -- from fishbowl_tag
from
    {{ ref('fishbowl_tag') }} as t
inner join
    {{ ref('fishbowl_location') }} as l
    on l.location_id = t.location_id -- Use renamed columns for join
where
    t.tag_type_id in (30, 40)        -- Use renamed column
group by
    l.location_group_id,
    t.part_id
