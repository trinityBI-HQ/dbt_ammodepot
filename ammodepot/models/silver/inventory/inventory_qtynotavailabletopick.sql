select
    t.part_id,                                   -- from fishbowl_tag
    l.location_group_id,                         -- from fishbowl_location
    COALESCE(
        SUM(t.quantity_on_tag - t.quantity_committed_on_tag), -- from fishbowl_tag
        0
    ) as quantity_not_available_to_pick
from
    {{ ref('fishbowl_tag') }} as t
inner join
    {{ ref('fishbowl_location') }} as l
    on l.location_id = t.location_id -- Use renamed columns for join
where
    t.tag_type_id in (30, 40)        -- Use renamed column
    and l.is_pickable = false         -- Use renamed and casted boolean column
    and l.location_type_id <> 100    -- Use renamed column
group by
    l.location_group_id,
    t.part_id
