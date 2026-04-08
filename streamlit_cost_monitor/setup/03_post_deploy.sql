-- ============================================================================
-- 03_post_deploy.sql — one-time grants after the Streamlit app is deployed
-- ============================================================================
-- Run ONCE after the first successful CI/CD deploy has created the
-- AD_ANALYTICS.OPS.COST_MONITOR Streamlit object.
--
-- Idempotent.
-- ============================================================================

use role accountadmin;

-- Attach the External Access Integration + secret to the Streamlit app.
-- Must be done after CREATE STREAMLIT; the GitHub Actions workflow can't
-- attach these itself because the deploy role (streamlit_role) doesn't own
-- the EAI.
alter streamlit ad_analytics.ops.cost_monitor set
    external_access_integrations = (aws_cost_explorer_integration)
    secrets = ('aws_cost_explorer_creds' = ad_analytics.ops.aws_cost_explorer_creds);

-- Viewer access for SSO users.
grant usage on streamlit ad_analytics.ops.cost_monitor to role dashboard_viewer_role;
grant usage on streamlit ad_analytics.ops.cost_monitor to role powerbi_readonly_role;

-- Sanity check — should show the EAI + secrets attached.
describe streamlit ad_analytics.ops.cost_monitor;
