-- ============================================================================
-- 02_create_secret.sql — write real AWS credentials into the Snowflake secret
-- ============================================================================
--
-- Run this AFTER the IAM user svc_snowflake_costs has been created in AWS.
-- The access-key + secret-key pair is printed to your terminal by
-- `setup/create_aws_iam_user.sh` — paste the values into the JSON below,
-- run the block, then DELETE the values from your shell history.
--
-- This file must NOT be committed with real credentials. Git-ignored by
-- default via .gitignore in this directory.
-- ============================================================================

use role accountadmin;

alter secret ad_analytics.ops.aws_cost_explorer_creds
    set secret_string = '{"access_key":"AKIA_REPLACE_ME","secret_key":"REPLACE_ME"}';

-- Verify — the value is encrypted, but you can confirm the secret exists
-- and has the expected bind on the integration:
desc secret ad_analytics.ops.aws_cost_explorer_creds;
desc external access integration aws_cost_explorer_integration;
