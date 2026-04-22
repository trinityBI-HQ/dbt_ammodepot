-- ============================================================================
-- Sales Dashboard — one-time bootstrap
-- ============================================================================
-- Run this ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. Stage for uploading Streamlit source files
--   2. Compute pool (CPU_X64_XS, 1 node, auto-suspend 300s)
--   3. Network rules (CARTO tiles + PyPI)
--   4. External Access Integration binding both rules
--   5. FinOps tags on compute pool
--   6. Grants for STREAMLIT_ROLE + viewer roles
--
-- Prereqs: AD_ANALYTICS.OPS schema + STREAMLIT_ROLE already exist
--          (created by cost monitor bootstrap).
-- ============================================================================

use role accountadmin;

-- ---------------------------------------------------------------------------
-- 1. Stage
-- ---------------------------------------------------------------------------

use role streamlit_role;
use schema ad_analytics.ops;

create stage if not exists sales_dashboard_stage
    directory = (enable = true)
    comment = 'Source stage for the Ammunition Depot Sales Dashboard Streamlit app';

-- ---------------------------------------------------------------------------
-- 2. Compute pool
-- ---------------------------------------------------------------------------

use role accountadmin;

create compute pool if not exists sales_dashboard_pool
    min_nodes = 1
    max_nodes = 1
    instance_family = cpu_x64_xs
    auto_resume = true
    auto_suspend_secs = 300
    comment = 'Streamlit container runtime for AD_ANALYTICS.OPS.SALES_DASHBOARD';

grant usage, monitor on compute pool sales_dashboard_pool to role streamlit_role;
grant usage on warehouse compute_wh to role streamlit_role;

-- CI/CD: SVC_DBT authenticates as STREAMLIT_ROLE for snow streamlit deploy
grant role streamlit_role to user svc_dbt;

-- ---------------------------------------------------------------------------
-- 3. Network rules — CARTO tiles + PyPI
-- ---------------------------------------------------------------------------

create or replace network rule ad_analytics.ops.carto_tiles_rule
    type = host_port
    mode = egress
    value_list = ('basemaps.cartocdn.com')
    comment = 'Egress to CARTO CDN for Scattermapbox dark tiles';

create or replace network rule ad_analytics.ops.sales_dashboard_pypi_rule
    type = host_port
    mode = egress
    value_list = ('pypi.org', 'files.pythonhosted.org')
    comment = 'Egress to PyPI for container runtime package installation';

grant usage on network rule ad_analytics.ops.carto_tiles_rule to role streamlit_role;
grant usage on network rule ad_analytics.ops.sales_dashboard_pypi_rule to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 4. External Access Integration
-- ---------------------------------------------------------------------------

create or replace external access integration sales_dashboard_integration
    allowed_network_rules = (
        ad_analytics.ops.carto_tiles_rule,
        ad_analytics.ops.sales_dashboard_pypi_rule
    )
    enabled = true
    comment = 'Sales dashboard -> CARTO tiles + PyPI for container runtime';

grant usage on integration sales_dashboard_integration to role streamlit_role;

-- ---------------------------------------------------------------------------
-- 5. FinOps tags (GOVERNANCE.TAGS provisioned by snowflake_setup/01_governance_tags.sql)
-- ---------------------------------------------------------------------------

alter compute pool sales_dashboard_pool set tag
    governance.tags.service = 'streamlit',
    governance.tags.client  = 'ammodepot';

-- ---------------------------------------------------------------------------
-- 6. Viewer grants
-- ---------------------------------------------------------------------------
-- Viewer roles get USAGE on schema (already granted by cost monitor bootstrap).
-- Streamlit object USAGE must be granted AFTER first deploy (object must exist).
-- Run post-deploy:
--
--   use role accountadmin;
--   grant usage on streamlit ad_analytics.ops.sales_dashboard
--     to role dashboard_viewer_role;
--   grant usage on streamlit ad_analytics.ops.sales_dashboard
--     to role powerbi_readonly_role;
