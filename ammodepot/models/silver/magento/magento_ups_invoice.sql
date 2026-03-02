-- STUB: ups_invoice is not available as a Magento stream.
-- The source data lives in a separate Snowflake schema (UPS_INVOICE_HISTORY).
-- TODO: Point this model to the actual UPS invoice source once located.
-- Both f_shippment and int_magento_order_freight use LEFT JOINs with coalesce()
-- fallbacks, so empty results here safely degrade to Fishbowl freight data.
select
    cast(null as varchar) as tracking_number,
    cast(null as float)   as net_amount
where 1 = 0
