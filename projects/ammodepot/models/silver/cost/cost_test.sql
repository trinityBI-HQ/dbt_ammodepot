{{ config(materialized='table', schema='silver') }}
SELECT
    z.total_cost                  AS cost,
    m.magento_order_item_identity AS magento_order,
    t.produto_magento             AS id_produto_magento,
    child.mgntid                  AS id_magento,
    z.so_item_id                  AS id_soitem,
    z.sales_order_id              AS order_fishbowl_id
FROM {{ ref('fishbowl_soitem') }}        AS z
LEFT JOIN {{ ref('conversion_soitem') }} AS child ON z.so_item_id  = child.idfb
LEFT JOIN {{ ref('conversion_product') }} AS t     ON z.product_id = t.produtofish
LEFT JOIN {{ ref('magento_identities') }} AS m     ON z.sales_order_id = m.code;
