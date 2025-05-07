{{
  config(
    materialized = 'view',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Core Identifiers
        entity_id,         -- Likely the primary key for the shipment grid record itself (often matches shipment ID)
        increment_id,      -- Shipment increment ID (user-facing)
        order_id,          -- Foreign Key to the Sales Order
        order_increment_id,-- Sales Order increment ID (user-facing)
        store_id,          -- Foreign Key to the Store

        -- Shipment Details
        total_qty,
        shipment_status,   -- Status code for the shipment
        shipping_name,
        shipping_address,  -- Formatted shipping address text
        shipping_information, -- Often contains carrier/method info

        -- Order Details (Denormalized onto the shipment grid)
        order_status,
        order_created_at,

        -- Customer Details (Denormalized)
        customer_name,
        customer_email,
        customer_group_id,

        -- Billing Details (Denormalized)
        billing_name,
        billing_address,   -- Formatted billing address text
        payment_method,

        -- Timestamps for the grid record/shipment
        created_at,
        updated_at,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded: Airbyte metadata, other CDC columns

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.TEST_DTO_2.SALES_SHIPMENT_GRID
        -- Assuming you have a dbt source named 'magento' pointing to AD_AIRBYTE.TEST_DTO_2
        {{ source('magento', 'sales_shipment_grid') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL marker.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    entity_id AS shipment_grid_id,      -- Renamed primary key (might often be same as shipment_id)
    increment_id AS shipment_increment_id,
    order_id AS order_id,
    order_increment_id AS order_increment_id,
    store_id AS store_id,

    -- Shipment Details
    total_qty AS total_quantity_shipped,
    shipment_status AS shipment_status_code, -- Renamed to indicate it's likely a code
    shipping_name,
    shipping_address AS shipping_address_text, -- Renamed for clarity
    shipping_information,

    -- Order Details
    order_status,
    order_created_at,

    -- Customer Details
    customer_name,
    customer_email,
    customer_group_id,

    -- Billing Details
    billing_name,
    billing_address AS billing_address_text, -- Renamed for clarity
    payment_method,

    -- Timestamps
    created_at AS shipment_created_at,      -- Renamed for clarity vs order dates
    updated_at AS shipment_updated_at       -- Renamed for clarity vs order dates

    -- No casting seems necessary based on DDL types for a Silver model

FROM
    source_data