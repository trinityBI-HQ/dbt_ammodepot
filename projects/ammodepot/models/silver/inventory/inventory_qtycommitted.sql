{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

SELECT
    t.part_id,                               -- from fishbowl_tag
    l.location_group_id,                     -- from fishbowl_location
    COALESCE(SUM(t.quantity_committed_on_tag), 0) AS quantity_committed -- from fishbowl_tag, renamed from qtyCommitted
FROM
    {{ ref('fishbowl_tag') }} t
JOIN
    {{ ref('fishbowl_location') }} l
    ON t.location_id = l.location_id -- Use renamed columns for join
GROUP BY
    t.part_id,
    l.location_group_id