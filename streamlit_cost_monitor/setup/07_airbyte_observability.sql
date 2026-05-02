-- ============================================================================
-- Airbyte Observability — destination-freshness monitor
-- ============================================================================
-- Run this ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. AD_ANALYTICS.OPS.AIRBYTE_FRESHNESS_THRESHOLDS — per-connection config
--   2. OPS_EMAIL_NOTIFICATIONS                       — account-level email
--   3. AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS          — connection-level view
--   4. AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS_PER_STREAM — stream-level view
--   5. AD_ANALYTICS.OPS.SP_SEND_AIRBYTE_FRESHNESS_EMAIL(tier) — email sender
--   6. AD_ANALYTICS.OPS.ALERT_AIRBYTE_FRESHNESS_WARN — edge-triggered WARN
--   7. AD_ANALYTICS.OPS.ALERT_AIRBYTE_FRESHNESS_ALERT — edge-triggered ALERT
--   8. Grants for DASHBOARD_VIEWER_ROLE and POWERBI_READONLY_ROLE
--
-- Pre-flight: run V-1, V-2, V-3, V-4 from the DESIGN doc first.
--   V-1: confirm median sync gap so you can tune warn/alert thresholds below
--   V-2: confirm fishbowl_s3=34, magento_s3=21, unmapped=0
--   V-3: confirm victor@trinitybi.com is a verified Snowflake user email
--   V-4: confirm EMAIL notification integration is supported on this account
--
-- If V-1 returns median gap > 30 min, change warn_minutes/alert_minutes below
-- to 90/180 before running.
-- ============================================================================

use role accountadmin;

-- ----------------------------------------------------------------------------
-- 1. Threshold config table
-- ----------------------------------------------------------------------------
-- Default thresholds assume ~15-min sync cadence (warn=30, alert=60).
-- If V-1 shows median gap > 30 min, change these to 90/180.
-- Tune post-deploy via UPDATE — no view recreation or redeploy needed.
-- ----------------------------------------------------------------------------

create table if not exists ad_analytics.ops.airbyte_freshness_thresholds (
    connection_id    varchar not null,
    warn_minutes     int     not null,
    alert_minutes    int     not null,
    comment          varchar,
    constraint pk_airbyte_freshness_thresholds primary key (connection_id),
    constraint chk_alert_gt_warn check (alert_minutes > warn_minutes)
);

merge into ad_analytics.ops.airbyte_freshness_thresholds as t
    using (
        select 'fishbowl_s3' as connection_id,
               30            as warn_minutes,
               60            as alert_minutes,
               'Fishbowl → S3 Iceberg (production2018 Glue db)' as comment
        union all
        select 'magento_s3', 30, 60,
               'Magento → S3 Iceberg (ammuni_prod Glue db)'
    ) as s
    on t.connection_id = s.connection_id
when not matched then
    insert (connection_id, warn_minutes, alert_minutes, comment)
    values (s.connection_id, s.warn_minutes, s.alert_minutes, s.comment);

grant ownership on table ad_analytics.ops.airbyte_freshness_thresholds
    to role streamlit_role copy current grants;
grant select on table ad_analytics.ops.airbyte_freshness_thresholds
    to role dashboard_viewer_role;
grant select on table ad_analytics.ops.airbyte_freshness_thresholds
    to role powerbi_readonly_role;

-- ----------------------------------------------------------------------------
-- 2. Email notification integration (account-level, reusable for future alerts)
-- ----------------------------------------------------------------------------
-- allowed_recipients must match a verified Snowflake user email (V-3).
-- To add recipients: ALTER NOTIFICATION INTEGRATION ops_email_notifications
--     SET ALLOWED_RECIPIENTS = ('victor@trinitybi.com', 'other@example.com');
-- ----------------------------------------------------------------------------

create notification integration if not exists ops_email_notifications
    type = email
    enabled = true
    allowed_recipients = ('victor@trinitybi.com')
    comment = 'Generic email channel for AD_ANALYTICS.OPS operational alerts. Reuse for future alert objects by granting USAGE on this integration.';

grant usage on integration ops_email_notifications to role streamlit_role;

-- ----------------------------------------------------------------------------
-- 3. Freshness views — built from explicit UNION ALL over all 55 landing tables
-- ----------------------------------------------------------------------------
-- Mapping rule:
--   table_name LIKE 'FISHBOWL_%' → connection_id = 'fishbowl_s3'
--   table_name LIKE 'MAGENTO_%'  → connection_id = 'magento_s3'
--
-- To add a third connection: add a new WHEN ... LIKE '<PREFIX>_%' clause to
-- the CASE in v_airbyte_freshness, and append UNION ALL blocks below.
--
-- Generated from bronze_fishbowl_sources.yml + bronze_magento_sources.yml
-- on 2026-05-01. To regenerate: read both YAML files, extract identifier:
-- values, and emit one UNION ALL block per table in the pattern below.
-- ----------------------------------------------------------------------------

-- streamlit_role owns ad_analytics.ops, but doesn't have SELECT on
-- ad_analytics.lakehouse_landing.*. accountadmin has both, and the views are
-- queryable by all consumers via the explicit grants below.
use role accountadmin;

-- 3a. Per-stream freshness view (detail level — used by dashboard table)
create or replace view ad_analytics.ops.v_airbyte_freshness_per_stream as
-- Fishbowl (34 tables) -------------------------------------------------------
select 'fishbowl_s3' as connection_id, 'FISHBOWL_CUSTOMER' as stream,
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)) as last_extracted_at,
    datediff('minute',
        max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
        current_timestamp()) as staleness_min
from ad_analytics.lakehouse_landing.fishbowl_customer
union all
select 'fishbowl_s3', 'FISHBOWL_PART',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_part
union all
select 'fishbowl_s3', 'FISHBOWL_SOITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_soitem
union all
select 'fishbowl_s3', 'FISHBOWL_SO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_so
union all
select 'fishbowl_s3', 'FISHBOWL_PRODUCT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_product
union all
select 'fishbowl_s3', 'FISHBOWL_SHIP',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_ship
union all
select 'fishbowl_s3', 'FISHBOWL_SHIPCARTON',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_shipcarton
union all
select 'fishbowl_s3', 'FISHBOWL_VENDOR',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_vendor
union all
select 'fishbowl_s3', 'FISHBOWL_PLUGININFO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_plugininfo
union all
select 'fishbowl_s3', 'FISHBOWL_UOMCONVERSION',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_uomconversion
union all
select 'fishbowl_s3', 'FISHBOWL_OBJECTTOOBJECT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_objecttoobject
union all
select 'fishbowl_s3', 'FISHBOWL_PARTCOST',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_partcost
union all
select 'fishbowl_s3', 'FISHBOWL_CARRIERSERVICE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_carrierservice
union all
select 'fishbowl_s3', 'FISHBOWL_VENDORPARTS',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_vendorparts
union all
select 'fishbowl_s3', 'FISHBOWL_INVENTORYLOG',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_inventorylog
union all
select 'fishbowl_s3', 'FISHBOWL_KITITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_kititem
union all
select 'fishbowl_s3', 'FISHBOWL_LOCATION',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_location
union all
select 'fishbowl_s3', 'FISHBOWL_PARTTRACKING',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_parttracking
union all
select 'fishbowl_s3', 'FISHBOWL_PARTTOTRACKING',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_parttotracking
union all
select 'fishbowl_s3', 'FISHBOWL_PO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_po
union all
select 'fishbowl_s3', 'FISHBOWL_POITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_poitem
union all
select 'fishbowl_s3', 'FISHBOWL_POST',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_post
union all
select 'fishbowl_s3', 'FISHBOWL_POSTPO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_postpo
union all
select 'fishbowl_s3', 'FISHBOWL_POSTPOITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_postpoitem
union all
select 'fishbowl_s3', 'FISHBOWL_RECEIPT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_receipt
union all
select 'fishbowl_s3', 'FISHBOWL_RECEIPTITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_receiptitem
union all
select 'fishbowl_s3', 'FISHBOWL_SERIAL',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_serial
union all
select 'fishbowl_s3', 'FISHBOWL_SERIALNUM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_serialnum
union all
select 'fishbowl_s3', 'FISHBOWL_TAG',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_tag
union all
select 'fishbowl_s3', 'FISHBOWL_TAGSERIALVIEW',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_tagserialview
union all
select 'fishbowl_s3', 'FISHBOWL_WO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_wo
union all
select 'fishbowl_s3', 'FISHBOWL_WOITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_woitem
union all
select 'fishbowl_s3', 'FISHBOWL_XO',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_xo
union all
select 'fishbowl_s3', 'FISHBOWL_XOITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.fishbowl_xoitem
-- Magento (21 tables) --------------------------------------------------------
union all
select 'magento_s3', 'MAGENTO_CUSTOMER_ENTITY',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_customer_entity
union all
select 'magento_s3', 'MAGENTO_CATALOG_CATEGORY_PRODUCT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_category_product
union all
select 'magento_s3', 'MAGENTO_CATALOG_CATEGORY_ENTITY_VARCHAR',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_category_entity_varchar
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_SUPER_LINK',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_super_link
union all
select 'magento_s3', 'MAGENTO_STORE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_store
union all
select 'magento_s3', 'MAGENTO_SALES_ORDER',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_sales_order
union all
select 'magento_s3', 'MAGENTO_SALES_ORDER_ITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_sales_order_item
union all
select 'magento_s3', 'MAGENTO_SALES_ORDER_ADDRESS',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_sales_order_address
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_ENTITY',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_entity
union all
select 'magento_s3', 'MAGENTO_SALES_SHIPMENT_GRID',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_sales_shipment_grid
union all
select 'magento_s3', 'MAGENTO_QUOTE_SHIPPING_RATE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_quote_shipping_rate
union all
select 'magento_s3', 'MAGENTO_QUOTE_ADDRESS',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_quote_address
union all
select 'magento_s3', 'MAGENTO_QUOTE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_quote
union all
select 'magento_s3', 'MAGENTO_QUOTE_ADDRESS_ITEM',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_quote_address_item
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_ENTITY_VARCHAR',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_entity_varchar
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_ENTITY_DECIMAL',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_entity_decimal
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_ENTITY_INT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_entity_int
union all
select 'magento_s3', 'MAGENTO_CATALOG_PRODUCT_ENTITY_TEXT',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_catalog_product_entity_text
union all
select 'magento_s3', 'MAGENTO_EAV_ATTRIBUTE_OPTION_VALUE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_eav_attribute_option_value
union all
select 'magento_s3', 'MAGENTO_EAV_ATTRIBUTE_SET',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_eav_attribute_set
union all
select 'magento_s3', 'MAGENTO_EAV_ATTRIBUTE',
    max(to_timestamp_ltz(_airbyte_extracted_at, 3)),
    datediff('minute', max(to_timestamp_ltz(_airbyte_extracted_at, 3)), current_timestamp())
from ad_analytics.lakehouse_landing.magento_eav_attribute
;

grant select on view ad_analytics.ops.v_airbyte_freshness_per_stream
    to role dashboard_viewer_role;
grant select on view ad_analytics.ops.v_airbyte_freshness_per_stream
    to role powerbi_readonly_role;
grant select on view ad_analytics.ops.v_airbyte_freshness_per_stream
    to role streamlit_role;

-- 3b. Connection-level freshness view (aggregated — used by KPI cards + alerts)
--
-- Aggregation rule: connection staleness = age of the BUSIEST stream's last
-- extract (MAX of MAX), NOT the oldest. Airbyte CDC only emits
-- _airbyte_extracted_at when rows actually change, so naturally-idle config
-- tables (eav_attribute_set, carrierservice, etc.) have stale extracts even
-- when the sync is fully healthy. Using MAX-of-MAX answers the right question:
-- "is anything still landing for this connection?". A stuck sync stops ALL
-- streams, so the busiest stream's freshness is the connection-level signal.
-- ----------------------------------------------------------------------------
create or replace view ad_analytics.ops.v_airbyte_freshness as
with connection_freshness as (
    select
        connection_id,
        min(last_extracted_at)  as oldest_extracted_at,  -- diagnostic only
        max(last_extracted_at)  as newest_extracted_at,  -- the alerting signal
        datediff(
            'minute',
            max(last_extracted_at),
            current_timestamp()
        )                       as staleness_min,
        count(*)                as table_count
    from ad_analytics.ops.v_airbyte_freshness_per_stream
    group by 1
)
select
    cf.connection_id,
    cf.oldest_extracted_at,
    cf.newest_extracted_at,
    cf.staleness_min,
    cf.table_count,
    t.warn_minutes,
    t.alert_minutes,
    case
        when cf.staleness_min >= t.alert_minutes then 'ALERT'
        when cf.staleness_min >= t.warn_minutes  then 'WARN'
        else 'OK'
    end as status
from connection_freshness as cf
left join ad_analytics.ops.airbyte_freshness_thresholds as t
    on cf.connection_id = t.connection_id;

grant select on view ad_analytics.ops.v_airbyte_freshness
    to role dashboard_viewer_role;
grant select on view ad_analytics.ops.v_airbyte_freshness
    to role powerbi_readonly_role;
grant select on view ad_analytics.ops.v_airbyte_freshness
    to role streamlit_role;

-- ----------------------------------------------------------------------------
-- 4. Body-builder stored procedure
-- ----------------------------------------------------------------------------
-- Test without touching alerts: CALL SP_SEND_AIRBYTE_FRESHNESS_EMAIL('WARN');
-- Runs as OWNER (streamlit_role), which has USAGE on ops_email_notifications.
-- QUERY_TAG is set inside the procedure so cost attribution works even if
-- session-level tags don't propagate from ALERT execution context.
-- ----------------------------------------------------------------------------

create or replace procedure ad_analytics.ops.sp_send_airbyte_freshness_email(tier varchar)
    returns varchar
    language sql
    execute as owner
as
$$
declare
    body        varchar;
    subj        varchar;
    has_rows    int;
begin
    -- Note: ALTER SESSION is not allowed inside Snowflake SQL stored
    -- procedures. Cost attribution for alert-issued queries is captured
    -- at the warehouse level (ETL_WH already tagged) and via the alert
    -- object's own QUERY_HISTORY entries.

    select count(*) into :has_rows
    from ad_analytics.ops.v_airbyte_freshness
    where status = :tier;

    if (:has_rows = 0) then
        return 'no rows match tier — skipping send';
    end if;

    select '[Airbyte ' || :tier || '] Sync freshness threshold crossed'
    into :subj;

    select
        'The following Airbyte connection(s) crossed the ' || :tier
            || ' staleness threshold:\n\n'
        || listagg(
                connection_id
                || ' — last extract '
                || staleness_min::varchar
                || ' min ago (newest stream: '
                || newest_extracted_at::varchar
                || ')',
                '\n'
           ) within group (order by connection_id)
        || '\n\nDashboard: open Streamlit Infra Monitor → Airbyte Health tab'
        || '\nRunbook:   https://github.com/trinitybi/dbt_ammodepot/blob/main'
               || '/docs/AIRBYTE_INCIDENT_RUNBOOK.md'
    into :body
    from ad_analytics.ops.v_airbyte_freshness
    where status = :tier;

    call system$send_email(
        'OPS_EMAIL_NOTIFICATIONS',
        'victor@trinitybi.com',
        :subj,
        :body
    );

    return 'sent — ' || :tier;
end;
$$;

grant usage on procedure ad_analytics.ops.sp_send_airbyte_freshness_email(varchar)
    to role streamlit_role;

-- ----------------------------------------------------------------------------
-- 5. Edge-triggered ALERT objects (WARN + ALERT tiers)
-- ----------------------------------------------------------------------------
-- Edge condition: the connection crossed into the target tier since the last
-- successful evaluation. We detect this via SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME().
--
-- If this function is not available in your account version, run:
--   SHOW FUNCTIONS LIKE '%SCHEDULED_TIME%' IN SCHEMA SNOWFLAKE.ALERT;
-- and substitute the correct function name in the IF EXISTS clauses below.
--
-- Both alerts run on ETL_WH at the same cron cadence as the dbt build so
-- ETL_WH is already warm — no 60s cold-start minimum charged per evaluation.
-- If the dbt cron changes, update these schedules to match.
-- ----------------------------------------------------------------------------

use role accountadmin;
grant execute alert on account to role streamlit_role;
grant execute task on account to role streamlit_role;
use role streamlit_role;

create or replace alert ad_analytics.ops.alert_airbyte_freshness_warn
    warehouse = etl_wh
    schedule = 'using cron 5,20,35,50 * * * * UTC'
    comment = 'Edge-triggered: fires once when a connection crosses WARN staleness. Cron synced to dbt build cadence to piggyback on a warm ETL_WH. Disable temporarily with: ALTER ALERT alert_airbyte_freshness_warn SUSPEND;'
if (
    exists (
        select 1
        from ad_analytics.ops.v_airbyte_freshness as curr
        where curr.status = 'WARN'
          and curr.staleness_min >= curr.warn_minutes
          and curr.staleness_min <  (
              select coalesce(
                  -- SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME() returns the
                  -- timestamp of the previous evaluation cycle as TIMESTAMP_LTZ.
                  -- See fallback note in header if this function is unavailable.
                  datediff(
                      'minute',
                      snowflake.alert.last_successful_scheduled_time(),
                      current_timestamp()
                  ) + curr.warn_minutes,
                  curr.warn_minutes + 1
              )
          )
    )
)
then
    call ad_analytics.ops.sp_send_airbyte_freshness_email('WARN');

alter alert ad_analytics.ops.alert_airbyte_freshness_warn resume;

create or replace alert ad_analytics.ops.alert_airbyte_freshness_alert
    warehouse = etl_wh
    schedule = 'using cron 5,20,35,50 * * * * UTC'
    comment = 'Edge-triggered: fires once when a connection crosses ALERT staleness. Separate from WARN alert so each tier can be independently suspended. Disable temporarily with: ALTER ALERT alert_airbyte_freshness_alert SUSPEND;'
if (
    exists (
        select 1
        from ad_analytics.ops.v_airbyte_freshness as curr
        where curr.status = 'ALERT'
          and curr.staleness_min >= curr.alert_minutes
          and curr.staleness_min < (
              select coalesce(
                  datediff(
                      'minute',
                      snowflake.alert.last_successful_scheduled_time(),
                      current_timestamp()
                  ) + curr.alert_minutes,
                  curr.alert_minutes + 1
              )
          )
    )
)
then
    call ad_analytics.ops.sp_send_airbyte_freshness_email('ALERT');

alter alert ad_analytics.ops.alert_airbyte_freshness_alert resume;

-- ----------------------------------------------------------------------------
-- 6. Viewer grants for Streamlit app consumers
-- ----------------------------------------------------------------------------

use role accountadmin;

grant usage on schema ad_analytics.ops to role powerbi_readonly_role;

-- Streamlit object USAGE grant runs via CI after `snow streamlit deploy`
-- (same pattern as the cost monitor -- see deploy-streamlit-cost-monitor.yml).
-- To grant manually after first deploy:
--   GRANT USAGE ON STREAMLIT ad_analytics.ops.infra_monitor
--       TO ROLE dashboard_viewer_role;
--   GRANT USAGE ON STREAMLIT ad_analytics.ops.infra_monitor
--       TO ROLE powerbi_readonly_role;

-- ============================================================================
-- Verification queries — run these by hand to confirm the bootstrap succeeded
-- ============================================================================
--
-- 1. Confirm both connections present with correct status:
--    SELECT * FROM ad_analytics.ops.v_airbyte_freshness;
--
-- 2. Confirm all 55 streams present (34 fishbowl + 21 magento):
--    SELECT connection_id, count(*) as stream_count
--    FROM ad_analytics.ops.v_airbyte_freshness_per_stream
--    GROUP BY 1;
--
-- 3. Send a test email (no alert needed):
--    CALL ad_analytics.ops.sp_send_airbyte_freshness_email('WARN');
--
-- 4. Confirm alerts are STARTED (not SUSPENDED):
--    SHOW ALERTS IN SCHEMA ad_analytics.ops;
--
-- 5. Synthetic threshold test — force a WARN fire:
--    UPDATE ad_analytics.ops.airbyte_freshness_thresholds
--        SET warn_minutes = 0 WHERE connection_id = 'fishbowl_s3';
--    -- Wait for next :05/:20/:35/:50 UTC; confirm email arrives
--    -- Then revert:
--    UPDATE ad_analytics.ops.airbyte_freshness_thresholds
--        SET warn_minutes = 30 WHERE connection_id = 'fishbowl_s3';
-- ============================================================================
