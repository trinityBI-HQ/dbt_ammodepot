with source_data as (

    select
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

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SHIP
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'ship') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Core Identifiers
    id as shipment_id,                  -- Renamed primary key
    num as shipment_number,
    shipmentidentificationnumber as shipment_identification_number,

    -- Related Order Identifiers
    soid as sales_order_id,
    poid as purchase_order_id,
    xoid as transfer_order_id,
    ordertypeid as order_type_id,

    -- Shipment Details
    statusid as status_id,
    carrierid as carrier_id,
    carrierserviceid as carrier_service_id,
    fobpointid as fob_point_id,
    cartoncount as carton_count,
    billoflading as bill_of_lading,
    contact as shipment_contact,
    shippedby as shipped_by_user_id,
    note as shipment_note,

    -- Shipping Address
    shiptoid as ship_to_id,
    shiptoname as ship_to_name,
    shiptoaddress as ship_to_address,
    shiptocity as ship_to_city,
    shiptozip as ship_to_zip,
    shiptostateid as ship_to_state_id,
    shiptocountryid as ship_to_country_id,
    CAST(shiptoresidential as BOOLEAN) as is_ship_to_residential,

    -- Location & Ownership
    locationgroupid as location_group_id,
    CAST(ownerisfrom as BOOLEAN) as owner_is_from, -- Rename based on actual meaning if known

    -- Timestamps
    datecreated as created_at,
    dateshipped as shipped_at,
    datelastmodified as last_modified_at,

    -- Custom Fields
    customfields as custom_fields

from
    source_data
