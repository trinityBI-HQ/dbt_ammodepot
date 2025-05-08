{{ config(
materialized = 'view',
schema       = 'silver'
) }}
WITH tagserialview_cte AS (
    SELECT
        l.location_group_id     AS location_group_id,
        t.location_id           AS location_id,
        t.part_id               AS part_id,
        t.tag_number            AS tag_number,
        ts.serial_number_value  AS serial_number,
        t.quantity_on_tag       AS quantity_on_tag
    FROM        {{ ref('fishbowl_location') }}            AS l
    JOIN        {{ ref('fishbowl_tag') }}                 AS t     ON    l.location_id = t.location_id
    LEFT JOIN   {{ ref('fishbowl_tagserialview') }}       AS ts    ON    ts.tag_id = t.tag_id
)
    SELECT
        location_group_id,
        location_id,
        part_id,
        tag_number,
        serial_number,
        ((1 - quantity_on_tag) * (COUNT(serial_number) - 1) + 1) AS calculated_quantity_on_hand
    FROM    tagserialview_cte
    GROUP BY
        location_group_id,
        location_id,
        part_id,
        tag_number,
        serial_number,
        quantity_on_tag
