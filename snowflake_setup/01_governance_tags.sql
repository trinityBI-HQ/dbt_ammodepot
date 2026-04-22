-- ============================================================================
-- FinOps Governance Tags — Multi-dimensional cost attribution
-- ============================================================================
-- Execution role: ACCOUNTADMIN
-- Execute via: snow sql -f snowflake_setup/01_governance_tags.sql
--              (or paste into a Snowsight worksheet as ACCOUNTADMIN)
--
-- Idempotent: every statement uses IF NOT EXISTS or SET (safe to re-run).
--
-- Creates:
--   - GOVERNANCE database + TAGS schema (account-level governance objects)
--   - Tag objects: service, environment, client
--   - Tag applications on service users, warehouses, compute pools, databases
--
-- Changes:
--   - SVC_DBT session QUERY_TAG default: 'dbt-transformation' -> 'dbt'
--     Per-model +query_tag in ammodepot/dbt_project.yml overrides this for
--     every ref()-driven query. The default only applies to on-run-start
--     hooks, source freshness, snapshot, and metadata queries — legitimately
--     "dbt" but not layer-scoped.
--
-- Reference:
--   .claude/rules/snowflake-finops-tagging.md
--   .claude/kb/data-engineering/data-platforms/snowflake/patterns/tag-governance.md
-- ============================================================================

use role accountadmin;

-- ----------------------------------------------------------------------------
-- 1. Governance database + schema
-- ----------------------------------------------------------------------------

create database if not exists governance
    comment = 'Account-level governance objects: tags, policies, audit views.';

create schema if not exists governance.tags
    comment = 'FinOps tag taxonomy — applied to users, warehouses, databases, pools.';

use schema governance.tags;

-- ----------------------------------------------------------------------------
-- 2. Tag objects (ALLOWED_VALUES enforced except on `client` which grows)
-- ----------------------------------------------------------------------------

create tag if not exists service
    allowed_values
        'dbt', 'airbyte', 'fivetran', 'dagster',
        'powerbi', 'streamlit', 'ad-hoc', 'shared-etl'
    comment = 'Workload owner. Applied to users, warehouses, compute pools.';

create tag if not exists environment
    allowed_values 'dev', 'staging', 'prod'
    comment = 'Environment. Applied to databases and schemas.';

create tag if not exists client
    comment = 'Client identifier for multi-tenant cost attribution.';

-- ----------------------------------------------------------------------------
-- 3. Apply `service` tag to service users
-- ----------------------------------------------------------------------------
-- Service accounts (confirmed present in the account):

alter user svc_dbt          set tag governance.tags.service = 'dbt';
alter user svc_airbyte      set tag governance.tags.service = 'airbyte';
alter user powerbi_reader   set tag governance.tags.service = 'powerbi';
alter user powerbi_ad       set tag governance.tags.service = 'powerbi';
alter user pc_fivetran_user set tag governance.tags.service = 'fivetran';
alter user trinity_mcp      set tag governance.tags.service = 'ad-hoc';
alter user mcp              set tag governance.tags.service = 'ad-hoc';

-- Legacy/unverified (uncomment after confirming whether still in use):
--   The AIRBYTE user exists alongside SVC_AIRBYTE — verify which one actually
--   runs syncs before tagging. Run the query in the commit notes to check.
-- alter user airbyte set tag governance.tags.service = 'airbyte';

-- Human users (tag as ad-hoc so interactive queries are separable in FinOps).
-- Omit anyone who should not be attributed to the ammodepot client (e.g.
-- trinityBI internal users running cross-client work):
--
-- alter user chris        set tag governance.tags.service = 'ad-hoc';
-- alter user dan          set tag governance.tags.service = 'ad-hoc';
-- alter user daniel_tbi   set tag governance.tags.service = 'ad-hoc';
-- alter user fabrizio_tbi set tag governance.tags.service = 'ad-hoc';
-- alter user rafaela      set tag governance.tags.service = 'ad-hoc';
-- alter user sethgoldy    set tag governance.tags.service = 'ad-hoc';
-- alter user victor       set tag governance.tags.service = 'ad-hoc';

-- Deprecated users (TEMP_USER_DELETE_AFTER…, TRINITYBI_USER_DELETE_A…):
-- should be DROPped, not tagged. Out of scope for this script.

-- Historical note: CLAUDE.md listed SVC_POWERBI as planned but it was never
-- provisioned. POWERBI_AD appears to be the actual AD-synced PBI account.

-- ----------------------------------------------------------------------------
-- 4. Apply `service` + `client` tags to warehouses
-- ----------------------------------------------------------------------------
-- ETL_WH is shared by Airbyte (legacy, mostly idle) and dbt. Tagged as
-- 'shared-etl' so the warehouse-level attribution stays honest; the per-query
-- user/tag dimensions split the actual credits.

alter warehouse etl_wh set tag
    governance.tags.service = 'shared-etl',
    governance.tags.client  = 'ammodepot';

alter warehouse compute_wh set tag
    governance.tags.service = 'powerbi',
    governance.tags.client  = 'ammodepot';

-- ----------------------------------------------------------------------------
-- 5. Apply tags to Streamlit compute pools
-- ----------------------------------------------------------------------------

alter compute pool sales_dashboard_pool set tag
    governance.tags.service = 'streamlit',
    governance.tags.client  = 'ammodepot';

alter compute pool cost_monitor_pool set tag
    governance.tags.service = 'streamlit',
    governance.tags.client  = 'ammodepot';

-- ----------------------------------------------------------------------------
-- 6. Apply `client` + `environment` tags to databases
-- ----------------------------------------------------------------------------

alter database ad_analytics set tag
    governance.tags.client      = 'ammodepot',
    governance.tags.environment = 'prod';

alter database ad_airbyte set tag
    governance.tags.client      = 'ammodepot',
    governance.tags.environment = 'prod';

-- ----------------------------------------------------------------------------
-- 7. Rename SVC_DBT session QUERY_TAG default
-- ----------------------------------------------------------------------------

alter user svc_dbt set query_tag = 'dbt';

-- ----------------------------------------------------------------------------
-- 8. Verification
-- ----------------------------------------------------------------------------
-- Tag applications (note: account_usage views have up to 2h latency):
--
--   select object_type, object_name, tag_name, tag_value
--   from snowflake.account_usage.tag_references
--   where tag_database = 'GOVERNANCE'
--     and tag_schema   = 'TAGS'
--   order by object_type, object_name, tag_name;
--
-- Cost attribution by service (credits by workload owner, last 30d):
--
--   select
--       svc.tag_value                                      as service,
--       round(sum(qah.credits_attributed_compute), 2)      as credits,
--       round(sum(qah.credits_attributed_compute) * 3, 2)  as usd
--   from snowflake.account_usage.query_attribution_history qah
--   join snowflake.account_usage.query_history qh
--       on qah.query_id = qh.query_id
--   left join snowflake.account_usage.tag_references svc
--       on  svc.object_name    = qh.user_name
--       and svc.object_domain  = 'USER'
--       and svc.tag_name       = 'SERVICE'
--   where qh.start_time >= dateadd(day, -30, current_timestamp())
--   group by 1
--   order by credits desc;
