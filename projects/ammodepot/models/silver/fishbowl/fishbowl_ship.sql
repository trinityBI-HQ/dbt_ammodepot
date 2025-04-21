{{
  config(
    materialized = 'table',
    schema = 'silver'
  )
}}

WITH source_data AS (

    SELECT
        -- Core Identifiers
        id,
        num,
        shipmentidentificationnumber, -- Likely a more specific shipment ID

        -- Related Order Identifiers
        soid, -- Sales Order ID
        poid, -- Purchase Order ID (if applicable)
        xoid, -- Transfer Order ID (if applicable)
        ordertypeid, -- Type of order this shipment is for

        -- Shipment Details
        statusid,
        carrierid,
        carrierserviceid,
        fobpointid,
        cartoncount,
        billoflading,
        contact, -- Contact person for the shipment
        shippedby, -- User ID who created/processed the shipment
        note,

        -- Shipping Address
        shiptoid, -- Link to a predefined ship-to location? (Check usage vs. address fields)
        shiptoname,
        shiptoaddress,
        shiptocity,
        shiptozip,
        shiptostateid,
        shiptocountryid,
        shiptoresidential, -- Boolean flag

        -- Location & Ownership
        locationgroupid, -- Originating location group
        ownerisfrom, -- Boolean flag (context needed, maybe related to ownership transfer?)

        -- Timestamps
        datecreated,
        dateshipped,
        datelastmodified,

        -- Custom Fields
        customfields,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    FROM
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SHIP
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'ship') }}
    WHERE
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at IS NULL
)

SELECT
    -- Core Identifiers
    id AS shipment_id,                  -- Renamed primary key
    num AS shipment_number,
    shipmentidentificationnumber AS shipment_identification_number,

    -- Related Order Identifiers
    soid AS sales_order_id,
    poid AS purchase_order_id,
    xoid AS transfer_order_id,
    ordertypeid AS order_type_id,

    -- Shipment Details
    statusid AS status_id,
    carrierid AS carrier_id,
    carrierserviceid AS carrier_service_id,
    fobpointid AS fob_point_id,
    cartoncount AS carton_count,
    billoflading AS bill_of_lading,
    contact AS shipment_contact,
    shippedby AS shipped_by_user_id,
    note AS shipment_note,

    -- Shipping Address
    shiptoid AS ship_to_id,
    shiptoname AS ship_to_name,
    shiptoaddress AS ship_to_address,
    shiptocity AS ship_to_city,
    shiptozip AS ship_to_zip,
    shiptostateid AS ship_to_state_id,
    shiptocountryid AS ship_to_country_id,
    CAST(shiptoresidential AS BOOLEAN) AS is_ship_to_residential,

    -- Location & Ownership
    locationgroupid AS location_group_id,
    CAST(ownerisfrom AS BOOLEAN) AS owner_is_from, -- Rename based on actual meaning if known

    -- Timestamps
    datecreated AS created_at,
    dateshipped AS shipped_at,
    datelastmodified AS last_modified_at,

    -- Custom Fields
    customfields AS custom_fields

FROM
    source_data