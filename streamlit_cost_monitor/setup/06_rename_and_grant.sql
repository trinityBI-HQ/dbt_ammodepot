-- ============================================================================
-- 06_rename_and_grant.sql — drop old COST_MONITOR, grant viewers on new
-- INFRA_MONITOR
-- ============================================================================
-- Run ONCE after first deploy with new name. Idempotent — safe to re-run.
-- ============================================================================

use role accountadmin;

-- Drop old object (if exists — safe to re-run)
drop streamlit if exists ad_analytics.ops.cost_monitor;

-- Re-grant viewer access on new object
grant usage on streamlit ad_analytics.ops.infra_monitor
    to role dashboard_viewer_role;
grant usage on streamlit ad_analytics.ops.infra_monitor
    to role powerbi_readonly_role;

-- Verify
describe streamlit ad_analytics.ops.infra_monitor;
