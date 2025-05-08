{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

SELECT
    t.part_id,                                   -- from fishbowl_tag
    l.location_group_id,                         -- from fishbowl_location
    COALESCE(
        SUM(t.quantity_on_tag - t.quantity_committed_on_tag), -- from fishbowl_tag
        0
    ) AS quantity_not_available_to_pick
FROM
    {{ ref('fishbowl_tag') }} t
JOIN
    {{ ref('fishbowl_location') }} l
    ON l.location_id = t.location_id -- Use renamed columns for join
WHERE
    t.tag_type_id IN (30, 40)        -- Use renamed column
    AND l.is_pickable IS FALSE         -- Use renamed and casted boolean column
    AND l.location_type_id <> 100    -- Use renamed column
GROUP BY
    l.location_group_id,
    t.part_id
