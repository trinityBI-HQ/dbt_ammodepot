select
    t.part_id,                               -- from fishbowl_tag
    l.location_group_id,                     -- from fishbowl_location
    COALESCE(SUM(t.quantity_committed_on_tag), 0) as quantity_committed -- from fishbowl_tag, renamed from qtyCommitted
from
    {{ ref('fishbowl_tag') }} as t
inner join
    {{ ref('fishbowl_location') }} as l
    on t.location_id = l.location_id -- Use renamed columns for join
group by
    t.part_id,
    l.location_group_id
