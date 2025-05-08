{{
  config(
    materialized = 'view',
    schema       = 'silver'
  )
}}

SELECT
    sn.part_tracking_id,               -- from fishbowl_serialnum
    s.serial_id,                       -- from fishbowl_serial
    pt.part_tracking_name,             -- from fishbowl_parttracking
    pt.part_tracking_abbreviation,     -- from fishbowl_parttracking
    pt.part_tracking_description,      -- from fishbowl_parttracking
    pt.sort_order AS part_tracking_sort_order, -- from fishbowl_parttracking, aliased for clarity
    pt.part_tracking_type_id,               -- from fishbowl_parttracking
    s.tag_id,                          -- from fishbowl_serial
    sn.serial_num_record_id,           -- from fishbowl_serialnum
    sn.serial_number_value,            -- from fishbowl_serialnum
    s.is_committed,                    -- from fishbowl_serial
    pt.is_active AS is_part_tracking_active -- from fishbowl_parttracking, aliased for clarity
FROM
    {{ ref('fishbowl_serial') }} s
JOIN
    {{ ref('fishbowl_serialnum') }} sn
    ON sn.serial_number_id = s.serial_id -- Use renamed columns for join
JOIN
    {{ ref('fishbowl_parttracking') }} pt -- Assuming a silver model named fishbowl_parttracking exists
    ON pt.part_tracking_id = sn.part_tracking_id -- Use renamed columns for join



