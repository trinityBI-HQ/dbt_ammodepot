-- ============================================================================
-- Airbyte Freeze Investigation — v1 evidence collector table
-- ============================================================================
-- Run this ONCE as ACCOUNTADMIN. Idempotent — safe to re-run.
--
-- Creates:
--   1. AD_ANALYTICS.OPS.AIRBYTE_FREEZE_EVIDENCE — one append-only row per
--      capture, written by the remediation Lambda BEFORE it touches the
--      cluster (capture-then-remediate). Protection stays enabled.
--   2. INSERT grant to TRANSFORMER_ROLE (Lambda authenticates as SVC_DBT).
--   3. SELECT grants to viewer roles.
--
-- PURPOSE (v1, deliberately narrow): let a downstream query answer ONE
-- question — "what is the first authoritative abnormal event that consistently
-- precedes an organic freeze?" The collector stores FACTS only; it never
-- records a conclusion. Hypothesis elimination happens in analysis (see the
-- derivation queries at the bottom), not here. The table carries the
-- discriminating signal for EVERY hypothesis and privileges none.
--
-- Deferred to v2 (build only if v1 captures prove the signal has decayed):
-- launcher jcmd deadlock detail, per-pod cgroup memory, event messages, an
-- early ~T0+10 job-progress poller. Each must first answer "what uncertainty
-- does this remove that the current evidence cannot?"
-- ============================================================================

use role accountadmin;

-- ----------------------------------------------------------------------------
-- 1. Append-only evidence table
-- ----------------------------------------------------------------------------
-- Volume: capture fires on every ALERT cron (incl. breaker-open re-fires, up to
-- ~8x/incident) x <=2 connections. Append-only is intentional: the repeated
-- captures across one incident ARE the timeline. Storage is negligible.
-- Freshness caveat lives in ANALYSIS: a signal captured at the freshness trigger
-- (~T0+30-45) may be decayed; k8s Events have a ~1h etcd TTL and coalesce. Treat
-- an event with count>1 or firstTs > attempt.createdAt as INFERRED, never as the
-- authoritative first-abnormal-event.
-- ----------------------------------------------------------------------------

create table if not exists ad_analytics.ops.airbyte_freeze_evidence (
    event_id         varchar(36)   not null,   -- FK to airbyte_remediation_log.event_id
    capture_time     timestamp_ntz not null default current_timestamp(),
    connection_id    varchar(64)   not null,   -- 'fishbowl_s3' | 'magento_s3'
    job_id           varchar(64),              -- Airbyte job id = FREEZE identity (distinct freezes = distinct job_id; many snapshots per freeze share it)
    capture_status   varchar(32)   not null,   -- ok | partial | empty | ssm_send_failed | ssm_poll_timeout | ssm_poll_error
    capture_detail   varchar(512),             -- non-null on a degraded capture
    attempt          variant,                  -- Airbyte latest job/attempt = the ONSET ANCHOR
    k8s_events       variant,                  -- earliest-25 Warning events, sorted ASC = the FAE bearer
    pods             variant,                  -- recent (<40m) pods: phase, restartCount, terminated, conditions
    node_conditions  variant,                  -- node MemoryPressure/DiskPressure/PIDPressure/Ready
    constraint pk_airbyte_freeze_evidence primary key (event_id),
    constraint chk_fe_connection check (connection_id in ('fishbowl_s3', 'magento_s3')),
    constraint chk_fe_status check (
        capture_status in ('ok', 'partial', 'empty', 'ssm_send_failed', 'ssm_poll_timeout', 'ssm_poll_error')
    )
);

-- ----------------------------------------------------------------------------
-- Retention decision (deliberately minimal for v1)
-- ----------------------------------------------------------------------------
-- RETAIN EVERYTHING during the investigation. Volume: capture fires only on an
-- ALERT breach (no freezes => zero rows), up to ~8x/incident x <=2 connections;
-- with VARIANT blobs capped (<=25 events, <=15 pods) this is a few KB/row and
-- single-digit MB/month worst case. No partitioning, no S3 archival, no clustering
-- is justified at this scale. Losing a capture mid-investigation is far costlier
-- than the storage. Once the investigation closes, enable a 90-day prune (owned by
-- the table owner so it has DELETE) — kept OUT of the active bootstrap to avoid a
-- scheduled TASK we do not yet need:
--
--   USE ROLE streamlit_role;  -- table owner (has DELETE)
--   CREATE OR REPLACE TASK ad_analytics.ops.tsk_airbyte_freeze_evidence_retention
--       WAREHOUSE = etl_wh
--       SCHEDULE  = 'USING CRON 0 6 * * * UTC'   -- 5-field UNIX cron, NOT Quartz
--       AS DELETE FROM ad_analytics.ops.airbyte_freeze_evidence
--          WHERE capture_time < DATEADD(day, -90, CURRENT_TIMESTAMP());
--   ALTER TASK ad_analytics.ops.tsk_airbyte_freeze_evidence_retention RESUME;

-- ----------------------------------------------------------------------------
-- 2. Ownership + grants (mirrors 08_airbyte_remediation_log.sql)
-- ----------------------------------------------------------------------------

grant ownership on table ad_analytics.ops.airbyte_freeze_evidence
    to role streamlit_role copy current grants;

grant insert on table ad_analytics.ops.airbyte_freeze_evidence
    to role transformer_role;

grant select on table ad_analytics.ops.airbyte_freeze_evidence
    to role dashboard_viewer_role;
grant select on table ad_analytics.ops.airbyte_freeze_evidence
    to role powerbi_readonly_role;
grant select on table ad_analytics.ops.airbyte_freeze_evidence
    to role streamlit_role;

-- ============================================================================
-- Analysis queries — run by hand once captures accrue (collection != conclusion)
-- ============================================================================
--
-- 1. First-abnormal-event per capture, derived from facts (the collector never
--    decides this). Earliest Warning event by its OWN server timestamp:
--
--    SELECT
--        fe.event_id,
--        fe.connection_id,
--        fe.capture_time,
--        fe.attempt:createdAt::timestamp_ltz              AS attempt_created_at,
--        e.value:reason::string                           AS first_reason,
--        e.value:firstTs::timestamp_ltz                   AS first_event_ts,
--        e.value:count::int                               AS event_count,
--        -- FRESHNESS GATE: only 'authoritative' rows may CONFIRM an FAE
--        CASE WHEN e.value:count::int > 1
--               OR e.value:firstTs::timestamp_ltz > fe.attempt:createdAt::timestamp_ltz
--             THEN 'inferred' ELSE 'authoritative' END    AS confidence
--    FROM ad_analytics.ops.airbyte_freeze_evidence fe,
--         LATERAL FLATTEN(input => fe.k8s_events) e
--    QUALIFY ROW_NUMBER() OVER (
--        PARTITION BY fe.event_id ORDER BY e.value:firstTs::timestamp_ltz ASC
--    ) = 1;
--
-- 2. Master-datum bisection (no event needed) — does a recent pod exist, and
--    in what state? absent => dispatch layer (H6/H7); present-but-terminated
--    => resource (H1); present+Pending => scheduler (H2):
--
--    SELECT event_id, connection_id, ARRAY_SIZE(pods) AS recent_pod_count,
--           pods FROM ad_analytics.ops.airbyte_freeze_evidence
--    WHERE connection_id = 'magento_s3' ORDER BY capture_time DESC;
--
-- 3. Invariant check — is the same authoritative first_reason present in >=4/5
--    distinct organic freezes? (the pre-registered CONFIRM bar). Run query 1
--    filtered to confidence='authoritative', GROUP BY first_reason.
-- ============================================================================
