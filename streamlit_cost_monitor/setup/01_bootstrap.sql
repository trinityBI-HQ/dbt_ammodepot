-- ============================================================================
-- Snowflake + AWS Cost Monitor — one-time bootstrap
-- ============================================================================
-- Run this ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. AD_ANALYTICS.OPS schema (owned by STREAMLIT_ROLE, home for the app)
--   2. Stage for uploading Streamlit source files
--   3. IMPORTED PRIVILEGES on SNOWFLAKE db (for ACCOUNT_USAGE access)
--   4. Network rule allowing egress to Cost Explorer (ce.us-east-1.amazonaws.com)
--   5. Generic-string secret holding the AWS access key JSON
--   6. External Access Integration binding the rule + secret
--   7. Viewer grants for DASHBOARD_VIEWER_ROLE
--
-- AFTER running this file, run 02_create_secret.sql with real AWS credentials.
-- ============================================================================

use role accountadmin;

-- ---------------------------------------------------------------------------
-- 1. Schema + stage
-- ---------------------------------------------------------------------------

create schema if not exists ad_analytics.ops
    comment = 'Operational dashboards — cost monitoring, alerting, housekeeping';

grant ownership on schema ad_analytics.ops to role streamlit_role copy current grants;
grant usage on database ad_analytics to role streamlit_role;

use role streamlit_role;
use schema ad_analytics.ops;

create stage if not exists cost_monitor_stage
    directory = (enable = true)
    comment = 'Source stage for the Snowflake + AWS Cost Monitor Streamlit app';

-- ---------------------------------------------------------------------------
-- 2. ACCOUNT_USAGE access (IMPORTED PRIVILEGES is account-level)
-- ---------------------------------------------------------------------------

use role accountadmin;

grant imported privileges on database snowflake to role streamlit_role;

-- STREAMLIT_ROLE owns the app; viewers read via USAGE on the Streamlit object,
-- which inherits the owner's rights for the queries it runs.
grant usage on warehouse compute_wh to role streamlit_role;

-- CI/CD: the GitHub Actions workflow authenticates as SVC_DBT (key-pair).
-- We grant STREAMLIT_ROLE to that user so `snow streamlit deploy` can run
-- with the correct owner role. No new service account needed.
grant role streamlit_role to user svc_dbt;

-- ---------------------------------------------------------------------------
-- 2b. Compute pool — Streamlit container runtime (GA 2026-03-09)
-- ---------------------------------------------------------------------------
-- Container runtime needs a Snowpark Container Services compute pool.
-- CPU_X64_XS is the smallest (2 vCPU, 8 GiB) — plenty for a cost monitor
-- with ~10 cached queries.  Auto-suspend at 5 min so we only pay while a
-- user is actively viewing the dashboard.
--
-- Cost (on-demand): ~0.06 credits/hour = ~$0.18/hour when active.
-- Expected usage: ~1 active hour/day = ~$5/month.

create compute pool if not exists cost_monitor_pool
    min_nodes = 1
    max_nodes = 1
    instance_family = cpu_x64_xs
    auto_resume = true
    auto_suspend_secs = 300
    comment = 'Streamlit container runtime for AD_ANALYTICS.OPS.COST_MONITOR';

grant usage, monitor on compute pool cost_monitor_pool to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 3. Network rule — egress to Cost Explorer
-- ---------------------------------------------------------------------------

create or replace network rule ad_analytics.ops.aws_cost_explorer_rule
    type = host_port
    mode = egress
    value_list = ('ce.us-east-1.amazonaws.com')
    comment = 'Egress to AWS Cost Explorer for the cost monitor app';

-- ---------------------------------------------------------------------------
-- 4. Placeholder secret (real value written by 02_create_secret.sql)
-- ---------------------------------------------------------------------------

create secret if not exists ad_analytics.ops.aws_cost_explorer_creds
    type = generic_string
    secret_string = '{"access_key":"PLACEHOLDER","secret_key":"PLACEHOLDER"}'
    comment = 'AWS IAM user svc_snowflake_costs — read-only Cost Explorer';

-- ---------------------------------------------------------------------------
-- 5. External Access Integration
-- ---------------------------------------------------------------------------

create or replace external access integration aws_cost_explorer_integration
    allowed_network_rules = (ad_analytics.ops.aws_cost_explorer_rule)
    allowed_authentication_secrets = (ad_analytics.ops.aws_cost_explorer_creds)
    enabled = true
    comment = 'Cost monitor → AWS Cost Explorer API';

grant usage on integration aws_cost_explorer_integration to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 6. Grants required for the app owner to read its own secret
-- ---------------------------------------------------------------------------

grant usage on schema ad_analytics.ops to role streamlit_role;
grant read on secret ad_analytics.ops.aws_cost_explorer_creds to role streamlit_role;
grant usage on network rule ad_analytics.ops.aws_cost_explorer_rule to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 7. Viewer grants — dashboard consumers can read the app only
-- ---------------------------------------------------------------------------

grant usage on schema ad_analytics.ops to role dashboard_viewer_role;
-- Streamlit object USAGE grant lives in 03_deploy.sql (after the app exists).
