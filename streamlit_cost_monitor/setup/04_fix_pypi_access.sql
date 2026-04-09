-- ============================================================================
-- 04_fix_pypi_access.sql — add PyPI egress for container runtime
-- ============================================================================
-- Run as ACCOUNTADMIN.
--
-- Problem: the container runtime installs packages from requirements.txt on
-- startup, which requires outbound HTTPS to pypi.org and
-- files.pythonhosted.org.  The original EAI only covered the AWS Cost
-- Explorer endpoint, so package installation fails with:
--   "Failed to fetch: https://pypi.org/simple/..."
--
-- Fix: add a second network rule for PyPI hosts and include it in the EAI.
-- Idempotent — safe to re-run.
-- ============================================================================

use role accountadmin;

-- 1. Network rule for PyPI package index + CDN
create or replace network rule ad_analytics.ops.pypi_rule
    type = host_port
    mode = egress
    value_list = ('pypi.org', 'files.pythonhosted.org')
    comment = 'Egress to PyPI for container runtime package installation';

grant usage on network rule ad_analytics.ops.pypi_rule to role streamlit_role;

-- 2. Rebuild the EAI to include both rules (keep the CE rule + add PyPI)
create or replace external access integration aws_cost_explorer_integration
    allowed_network_rules = (
        ad_analytics.ops.aws_cost_explorer_rule,
        ad_analytics.ops.pypi_rule
    )
    allowed_authentication_secrets = (ad_analytics.ops.aws_cost_explorer_creds)
    enabled = true
    comment = 'Cost monitor → AWS Cost Explorer API + PyPI for container runtime';

grant usage on integration aws_cost_explorer_integration to role streamlit_role;

-- 3. Re-attach to the Streamlit object so the updated EAI takes effect
alter streamlit ad_analytics.ops.cost_monitor set
    external_access_integrations = (aws_cost_explorer_integration)
    secrets = ('aws_cost_explorer_creds' = ad_analytics.ops.aws_cost_explorer_creds);

-- Verify
describe streamlit ad_analytics.ops.cost_monitor;
