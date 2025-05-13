{{
  config(
    materialized = 'table',
    schema       = 'gold'
  )
}}

WITH kits AS (
    -- Identify kit components and their parent kit product
    SELECT
        kt.component_product_id,        -- from fishbowl_kititem (renamed from productid)
        kt.kit_product_id,              -- from fishbowl_kititem (renamed from kitproductid)
        pd.product_number AS individual_num, -- from fishbowl_product (renamed from num)
        kt.default_quantity,            -- from fishbowl_kititem (renamed from defaultqty)
        pt.product_number AS num_bundle      -- from fishbowl_product (renamed from num)
    FROM
        {{ ref('fishbowl_kititem') }} kt
    LEFT JOIN
        {{ ref('fishbowl_product') }} pd
        ON kt.component_product_id = pd.product_id -- Use silver renamed columns
    LEFT JOIN
        {{ ref('fishbowl_product') }} pt
        ON kt.kit_product_id = pt.product_id -- Use silver renamed columns
    WHERE
        kt.kit_type_id = 10 -- Use silver renamed column
        AND pd.product_number NOT LIKE '%POLLYAMOBAG%'
        AND pd.product_number NOT LIKE '%POLYAMMOBAG%'
),

fishbowl_conversion_cost AS (
    -- Calculate average UOM conversion factor and average cost per product number
    SELECT
        pr.product_number,                 -- Use silver renamed column
        AVG(uom.multiply_factor) AS conversion_factor, -- Use silver renamed column, better alias
        AVG(pc.average_cost) AS average_cost        -- Use silver renamed column, better alias
    FROM
        {{ ref('fishbowl_product') }} pr
    LEFT JOIN
        {{ ref('fishbowl_uomconversion') }} uom
        ON pr.uom_id = uom.from_uom_id AND uom.to_uom_id = 1 -- Use silver renamed columns
    LEFT JOIN
        {{ ref('fishbowl_partcost') }} pc
        ON pr.part_id = pc.part_id -- Use silver renamed columns
    GROUP BY
        pr.product_number
)

-- Final selection combining kit info with conversion rates
SELECT
    kt.component_product_id,
    kt.kit_product_id,
    kt.individual_num,
    kt.default_quantity,
    kt.num_bundle,
    COALESCE(fc.conversion_factor, 1) * kt.default_quantity AS conversion_rate, -- Renamed alias
    'KIT' AS kit_type -- Renamed alias
FROM
    kits kt
LEFT JOIN
    fishbowl_conversion_cost fc
    ON kt.individual_num = fc.product_number