-- ============================================================================
-- Airbyte Auto-Remediation — audit log table (Phase 2)
-- ============================================================================
-- Run this ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG — one row per Lambda
--      invocation that took action / escalated / blocked-on-breaker /
--      would-act-in-observe.
--   2. INSERT grant to TRANSFORMER_ROLE (Lambda authenticates as SVC_DBT
--      which uses TRANSFORMER_ROLE).
--   3. SELECT grants to DASHBOARD_VIEWER_ROLE + POWERBI_READONLY_ROLE +
--      STREAMLIT_ROLE (so dashboards can read).
--
-- Out of scope (Phase 2.5+): retention archival via TASK. The table is
-- expected to receive ~5–60 rows/year at production volume; storage cost
-- is essentially zero.
-- ============================================================================

use role accountadmin;

-- ----------------------------------------------------------------------------
-- 1. Audit log table
-- ----------------------------------------------------------------------------

create table if not exists ad_analytics.ops.airbyte_remediation_log (
    event_id              varchar(36)    not null,    -- Lambda request_id (UUID)
    event_time            timestamp_ntz  not null     default current_timestamp(),
    incident_started_at   timestamp_ltz,              -- newest_extracted_at when Lambda fired
    connection_id         varchar(64)    not null,    -- 'fishbowl_s3' | 'magento_s3'
    tier                  varchar(16)    not null,    -- 'ALERT' (we don't act on WARN)
    action_taken          varchar(32),                -- 'cancel_and_restart' | 'would_cancel_and_restart' | 'none' | NULL
    pre_staleness_min     int,                        -- staleness when Lambda fired
    post_staleness_min    int,                        -- staleness after 5-min wait (verification)
    cancelled_job_id      varchar(64),
    restart_job_id        varchar(64),
    outcome               varchar(32)    not null,
    failure_reason        varchar(512),               -- NULL on AUTO_FIX
    verification_method   varchar(48),                -- 'snowflake_view_refreshed' | 's3_list_recent_fallback' | 'both_inconclusive_escalated' | NULL
    lambda_request_id     varchar(36)    not null,    -- duplicate of event_id, kept for join clarity
    lambda_log_stream     varchar(256),               -- /aws/lambda/airbyte-auto-remediate/[date]/[stream]
    breaker_until_at      timestamp_ltz,              -- breaker expiry, populated on ESCALATE
    constraint pk_airbyte_remediation_log primary key (event_id),
    constraint chk_outcome check (
        outcome in (
            'AUTO_FIX',
            'ESCALATE',
            'BREAKER_OPEN',
            'OBSERVE_ONLY_WOULD_ACT'
        )
    ),
    constraint chk_tier check (tier = 'ALERT'),
    constraint chk_connection check (connection_id in ('fishbowl_s3', 'magento_s3'))
);

-- ----------------------------------------------------------------------------
-- 2. Ownership + grants
-- ----------------------------------------------------------------------------
-- STREAMLIT_ROLE owns AD_ANALYTICS.OPS (per ops-schema-ownership rule);
-- TRANSFORMER_ROLE needs INSERT for Lambda; viewer roles get SELECT.
-- ----------------------------------------------------------------------------

grant ownership on table ad_analytics.ops.airbyte_remediation_log
    to role streamlit_role copy current grants;

grant insert on table ad_analytics.ops.airbyte_remediation_log
    to role transformer_role;

grant select on table ad_analytics.ops.airbyte_remediation_log
    to role dashboard_viewer_role;
grant select on table ad_analytics.ops.airbyte_remediation_log
    to role powerbi_readonly_role;
grant select on table ad_analytics.ops.airbyte_remediation_log
    to role streamlit_role;

-- ============================================================================
-- Reconciliation query — used by AT-008 (audit completeness)
-- ============================================================================
-- SELECT count(*) FROM ad_analytics.ops.airbyte_remediation_log
-- WHERE event_time >= dateadd('day', -7, current_timestamp())
--   AND outcome IN ('AUTO_FIX','ESCALATE','BREAKER_OPEN','OBSERVE_ONLY_WOULD_ACT');
-- Compare against CloudWatch invocation count where action was taken.
-- ============================================================================

-- ============================================================================
-- Verification queries — run by hand after bootstrap
-- ============================================================================
--
-- 1. Confirm table exists with constraints:
--    DESCRIBE TABLE ad_analytics.ops.airbyte_remediation_log;
--
-- 2. Confirm ownership + grants:
--    SHOW GRANTS ON TABLE ad_analytics.ops.airbyte_remediation_log;
--
-- 3. Test INSERT path as TRANSFORMER_ROLE (Lambda persona):
--    USE ROLE transformer_role;
--    INSERT INTO ad_analytics.ops.airbyte_remediation_log
--        (event_id, connection_id, tier, outcome, lambda_request_id)
--        VALUES (uuid_string(), 'fishbowl_s3', 'ALERT', 'AUTO_FIX', uuid_string());
--    DELETE FROM ad_analytics.ops.airbyte_remediation_log
--        WHERE event_id = (SELECT MAX(event_id) FROM ad_analytics.ops.airbyte_remediation_log);
-- ============================================================================
