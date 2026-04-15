-- ============================================================================
-- 05_add_cloudwatch_egress.sql — add CloudWatch + Logs egress for dbt
-- pipeline monitoring
-- ============================================================================
-- Run as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Adds a network rule for CloudWatch Metrics + Logs APIs and rebuilds the
-- EAI to include it alongside the existing CE + PyPI rules.
-- ============================================================================

use role accountadmin;

-- 1. Network rule for CloudWatch metrics + logs + S3 (presigned URL generation)
create or replace network rule ad_analytics.ops.cloudwatch_rule
    type = host_port
    mode = egress
    value_list = (
        'monitoring.us-east-1.amazonaws.com',
        'logs.us-east-1.amazonaws.com',
        'ammodepot-lakehouse.s3.us-east-1.amazonaws.com',
        's3.us-east-1.amazonaws.com'
    )
    comment = 'Egress to CloudWatch Metrics + Logs + S3 for dbt pipeline monitoring';

grant usage on network rule ad_analytics.ops.cloudwatch_rule
    to role streamlit_role;

-- 2. Rebuild EAI with all three rules (CE + PyPI + CloudWatch)
create or replace external access integration aws_cost_explorer_integration
    allowed_network_rules = (
        ad_analytics.ops.aws_cost_explorer_rule,
        ad_analytics.ops.pypi_rule,
        ad_analytics.ops.cloudwatch_rule
    )
    allowed_authentication_secrets = (ad_analytics.ops.aws_cost_explorer_creds)
    enabled = true
    comment = 'Infra monitor → AWS Cost Explorer + PyPI + CloudWatch';

grant usage on integration aws_cost_explorer_integration
    to role streamlit_role;

-- 3. Re-attach to the CURRENT Streamlit object so the updated EAI takes
--    effect immediately. After CI deploys with the new snowflake.yml
--    (identifier: infra_monitor), the deploy workflow's re-attach step
--    will bind the EAI to the new object automatically.
alter streamlit ad_analytics.ops.cost_monitor set
    external_access_integrations = (aws_cost_explorer_integration)
    secrets = ('aws_cost_explorer_creds' = ad_analytics.ops.aws_cost_explorer_creds);

-- Verify
describe streamlit ad_analytics.ops.cost_monitor;
