{{ config(materialized='table', schema='silver') }}
SELECT
    object1_record_id    AS recordid1,
    object2_record_id    AS recordid2,
    relationship_type_id AS typeid
FROM {{ ref('fishbowl_objecttoobject') }}
WHERE relationship_type_id = 30;
