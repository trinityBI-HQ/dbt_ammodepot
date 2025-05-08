{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

SELECT
    t.part_id,                         -- from fishbowl_tag
    l.location_group_id,               -- from fishbowl_location
    COALESCE(SUM(t.quantity_on_tag), 0) AS quantity_on_hand -- from fishbowl_tag
FROM
    {{ ref('fishbowl_tag') }} t
JOIN
    {{ ref('fishbowl_location') }} l
    ON l.location_id = t.location_id -- Use renamed columns for join
WHERE
    t.tag_type_id IN (30, 40)        -- Use renamed column
GROUP BY
    l.location_group_id,
    t.part_id
