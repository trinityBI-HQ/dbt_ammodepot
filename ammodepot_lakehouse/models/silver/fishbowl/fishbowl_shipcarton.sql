with source_data as (

    select
        -- Identifiers
        id,
        shipid,           -- Link to the parent shipment record
        orderid,          -- Link to the original order
        cartonnum,        -- Carton sequence number for the shipment/order
        sscc,             -- Serial Shipping Container Code (often used for EDI/logistics)
        trackingnum,      -- Carrier tracking number for this carton

        -- Dimensions & Weight
        len,
        width,
        height,
        sizeuom,          -- Unit of Measure for dimensions
        freightweight,    -- Weight used for freight calculation
        weightuom,        -- Unit of Measure for weight

        -- Financials & Handling
        insuredvalue,
        freightamount,
        additionalhandling, -- Boolean flag
        shipperrelease,     -- Boolean flag

        -- Relationships & Context
        carrierid,
        ordertypeid,      -- Type of the related order (e.g., SO, PO)

        -- Timestamps
        datecreated,

        -- CDC Column for filtering
        _ab_cdc_deleted_at

        -- Columns excluded (examples):
        -- _AIRBYTE_RAW_ID, _AIRBYTE_EXTRACTED_AT, _AIRBYTE_META, _AIRBYTE_GENERATION_ID
        -- _AB_CDC_CURSOR, _AB_CDC_LOG_POS, _AB_CDC_LOG_FILE, _AB_CDC_UPDATED_AT

    from
        -- Source is defined in DDL as AD_AIRBYTE.AIRBYTE_SCHEMA.SHIPCARTON
        -- Assuming you have a dbt source named 'ad_airbyte' pointing to AD_AIRBYTE.AIRBYTE_SCHEMA
        {{ source('fishbowl', 'shipcarton') }}
    where
        -- Filter out soft deletes. Note: Your DDL shows _ab_cdc_deleted_at as VARCHAR.
        -- This IS NULL check assumes it behaves like a standard timestamp NULL.
        -- If deletion is marked by empty strings or specific text, adjust this condition.
        _ab_cdc_deleted_at is null
)

select
    -- Identifiers
    id as ship_carton_id,       -- Renamed primary key
    shipid as shipment_id,      -- Renamed foreign key to shipment
    orderid as order_id,        -- Renamed foreign key to order
    cartonnum as carton_number,
    sscc as sscc_code,
    trackingnum as tracking_number,

    -- Dimensions & Weight
    len as length,
    width,
    height,
    sizeuom as size_uom,
    freightweight as freight_weight,
    weightuom as weight_uom,

    -- Financials & Handling
    insuredvalue as insured_value,
    freightamount as freight_amount,
    CAST(additionalhandling as BOOLEAN) as requires_additional_handling,
    CAST(shipperrelease as BOOLEAN) as is_shipper_release,

    -- Relationships & Context
    carrierid as carrier_id,
    ordertypeid as order_type_id,

    -- Timestamps
    datecreated as created_at

from
    source_data
