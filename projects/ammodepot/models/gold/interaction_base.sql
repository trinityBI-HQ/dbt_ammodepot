{{ config(materialized='table', schema='gold') }}
SELECT
    convert_timezone('UTC','America/New_York',z.item_created_at::timestamp) AS created_at,
    z.product_id,
    z.order_id,
    CASE WHEN z.row_total <> 0
         THEN (z.quantity_ordered * z.row_total) / z.row_total
         ELSE 0 END                                              AS qty_ordered,
    z.discount_amount,
    z.discount_invoiced,
    CAST(z.product_id AS VARCHAR) || '@' || CAST(z.order_id AS VARCHAR)    AS chave,
    /* Consolidated cost logic */
    COALESCE(u.cost,d.cost,a2.cost,
             u.averageweightedcost * z.quantity_ordered,
             d.averageweightedcost * z.quantity_ordered,
             a2.averageweightedcost * z.quantity_ordered)        AS cost,
    COALESCE(u.averageweightedcost,d.averageweightedcost,a2.averageweightedcost)
                                                                AS averageweightedcost,
    z.tax_amount,
    z.row_total - COALESCE(z.amount_refunded,0)
                - COALESCE(z.discount_amount,0)
                + COALESCE(z.discount_refunded,0)                AS row_total,
    o.order_increment_id                                         AS increment_id,
    o.billing_address_id,
    o.customer_email,
    a.postcode,
    a.country_code                                               AS country,
    a.region,
    a.city,
    a.street_address                                             AS street,
    a.phone_number                                               AS telephone,
    o.customer_firstname || ' ' || o.customer_lastname          AS customer_name,
    z.base_cost                                                  AS cost_magento,
    z.order_item_id,
    o.order_status                                               AS order_status,
    sp.cost                                                      AS fishbowl_registeredcost,
    z.store_id,
    o.store_name,
    z.item_weight                                                AS weight,
    z.product_options,
    z.product_type,
    z.parent_item_id,
    z.sku                                                        AS testsku,
    z.applied_rule_ids,
    o.customer_id,
    z.vendor_id
FROM {{ ref('magento_sales_order_item') }} AS z
LEFT JOIN {{ ref('magento_sales_order') }}  AS o  ON z.order_id = o.order_id
LEFT JOIN {{ ref('magento_sales_order_address') }} AS a ON o.billing_address_id = a.order_address_id
LEFT JOIN {{ ref('cost_unique_magento_id') }}       AS u  ON z.order_item_id = u.id_magento
LEFT JOIN {{ ref('cost_duplicate_magento_id_product') }} AS d
       ON z.order_item_id = d.id_magento
      AND z.product_id   = d.id_produto_magento
LEFT JOIN {{ ref('cost_duplicate_magento_id_avg') }} AS a2 ON z.order_item_id = a2.id_magento
LEFT JOIN {{ ref('status_processing_costs') }}      AS sp ON z.order_id     = sp.order_id;
