"""airbyte-auto-remediate — Lambda handler.

Single-invocation orchestration:
  1. Read flags + state (SSM Parameter, Secrets Manager, DynamoDB)
  2. Detect ALERT-tier breaches (Snowflake V_AIRBYTE_FRESHNESS)
  3. For each breached connection (parallel via ThreadPoolExecutor):
     a. Check breaker (skip if open)
     b. Check observe-only (log decision; skip action)
     c. Tier 1: Cancel + restart via SSM SendCommand
     d. Sleep 300 s
     e. Verify: Snowflake re-query first; S3 LIST per-table fallback
     f. Tier 2 (Phase 2.1, kind-bounce): fire if EITHER
          - post_staleness > 60 (deep_stuck), OR
          - ≥2 cancel_and_restart attempts on this connection in last
            240 min (repeat_pattern — catches recurring-incident clusters;
            window must exceed the 2h per-connection breaker floor)
        and gates clear (cooldown, concurrent-sync). docker restart
        airbyte-abctl-control-plane via SSM (reconciled up to 240s), then on
        SUCCESS auto cancel+restart to kick a fresh sync, sleep 180s, re-verify.
     g. Determine outcome
  4. Persist + notify (Snowflake audit row + ClickUp comment + SNS publish)

Time budget per connection (cap-based worst case, with Tier 2 firing):
  detect 2s + (cancel+restart poll ≤120s SSM) + sleep 300s + verify 10s
  + eligibility 5s + (kind-bounce reconcile ≤240s SSM) + (post-bounce
  cancel+restart poll ≤45s) + sleep 180s + verify 10s + notify 5s ≈ 920s at the
  caps. The KIND_BOUNCE_VERIFY_WAIT sleep + verify is GUARDED by _has_budget_for
  against the 900s hard timeout: if the invocation lacks budget it writes a
  "verify deferred" row (cooldown already open) and lets the next cron cycle's
  freshness check confirm recovery, so an overrun can never hard-kill mid-tier.
"""

from __future__ import annotations

import json
import logging
import os
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path

import boto3
import requests
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import snowflake.connector

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

AIRBYTE_INSTANCE_ID = "i-075043415ebad732f"

AIRBYTE_CONNECTION_IDS = {
    "fishbowl_s3": "4bfd4a15-29d6-4c2e-893a-94f211d3596d",
    "magento_s3":  "ad733fe4-54d9-4e0e-8869-a7ea9d91d450",
}

# Real S3 layout (verified 2026-05-03 via V-4): iceberg/<glue_db>.db/<table>/
# DESIGN had wrong path — corrected here.
S3_PREFIXES = {
    "fishbowl_s3": "iceberg/production2018.db/",
    "magento_s3":  "iceberg/ammuni_prod.db/",
}

# Busiest table per connection — used as canary for fast S3-LIST verification.
# Listing the whole Glue DB prefix takes ~2 min; per-table listing is ~5s.
S3_CANARY_TABLES = {
    "fishbowl_s3": "soitem",
    "magento_s3":  "sales_order_item",
}

LAKEHOUSE_BUCKET = "ammodepot-lakehouse"

SNOW_AUDIT_TABLE = "ad_analytics.ops.airbyte_remediation_log"
SNOW_FRESHNESS_VIEW = "ad_analytics.ops.v_airbyte_freshness"

DDB_TABLE = os.environ.get("DDB_TABLE", "airbyte-auto-remediate-state")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
CLICKUP_TASK_ID = os.environ.get("CLICKUP_TASK_ID", "86ah8bpmj")

OBSERVE_ONLY_PARAM = "/airbyte-auto-remediate/observe-only"
SECRET_SNOWFLAKE = os.environ.get("SECRET_SNOWFLAKE", "ammodepot/dbt/snowflake")
SECRET_CLICKUP = os.environ.get("SECRET_CLICKUP", "ammodepot/airbyte-auto-remediate/clickup")

VERIFY_WAIT_SECONDS = int(os.environ.get("VERIFY_WAIT_SECONDS", "300"))
BREAKER_LOCK_SECONDS = int(os.environ.get("BREAKER_LOCK_SECONDS", "7200"))
SSM_POLL_TIMEOUT_SECONDS = int(os.environ.get("SSM_POLL_TIMEOUT_SECONDS", "120"))
SSM_POLL_INTERVAL_SECONDS = 5
# Terminal SSM command-invocation statuses (poll target).
_SSM_TERMINAL_STATUSES = ("Success", "Failed", "TimedOut", "Cancelled")

SSM_PAYLOAD_TEMPLATE_PATH = Path(__file__).parent / "ssm-payloads" / "cancel_and_restart.json.tmpl"

KIND_BOUNCE_OBSERVE_ONLY_PARAM = "/airbyte-auto-remediate/kind-bounce-observe-only"
KIND_BOUNCE_TRIGGER_POST_MIN = int(os.environ.get("KIND_BOUNCE_TRIGGER_POST_MIN", "60"))
KIND_BOUNCE_VERIFY_WAIT_SECONDS = int(os.environ.get("KIND_BOUNCE_VERIFY_WAIT_SECONDS", "180"))
KIND_BOUNCE_COOLDOWN_SECONDS = int(os.environ.get("KIND_BOUNCE_COOLDOWN_SECONDS", "21600"))
# A control-plane restart legitimately outlasts the 120s primary SSM poll
# (the payload waits up to 120s for readiness on top of up to ~60s SSM delivery
# latency). Reconcile by polling to this window before classifying the command,
# so a still-running bounce is never mislabeled a failure. Worst-case tier
# timing with 240s here stays under the 900s Lambda ceiling (budget noted in
# _execute_kind_bounce_tier).
KIND_BOUNCE_SSM_RECONCILE_SECONDS = int(os.environ.get("KIND_BOUNCE_SSM_RECONCILE_SECONDS", "240"))
# Invariant: reconcile MUST exceed the primary poll, else Phase 2 collapses to a
# zero-length no-op and every slow bounce is misclassified UNKNOWN (the SUCCESS
# path — cooldown + fresh-sync kick — would never run). Clamp defensively.
if KIND_BOUNCE_SSM_RECONCILE_SECONDS <= SSM_POLL_TIMEOUT_SECONDS:
    KIND_BOUNCE_SSM_RECONCILE_SECONDS = SSM_POLL_TIMEOUT_SECONDS + 120
# Post-bounce cancel+restart is non-fatal (only kicks a fresh sync + labels the
# audit row), so poll it briefly rather than the full 120s — it runs against a
# just-restarted, still-stabilizing control plane and would otherwise be the
# largest avoidable contributor to the invocation's worst-case time.
KIND_BOUNCE_POST_RESTART_POLL_SECONDS = int(os.environ.get("KIND_BOUNCE_POST_RESTART_POLL_SECONDS", "45"))
# Safety margin over the KIND_BOUNCE_VERIFY_WAIT sleep before we risk the 900s
# Lambda hard timeout; below this the in-line verify is deferred to next cycle.
KIND_BOUNCE_VERIFY_BUDGET_MARGIN_SECONDS = 30

# _ssm_kind_bounce outcome classification (see its docstring).
KIND_BOUNCE_SSM_SUCCESS = "SUCCESS"
KIND_BOUNCE_SSM_FAILED = "FAILED"
KIND_BOUNCE_SSM_UNKNOWN = "UNKNOWN"
KIND_BOUNCE_REPEAT_COUNT = int(os.environ.get("KIND_BOUNCE_REPEAT_COUNT", "2"))
# Default 240 min (4h) — must exceed the 2h per-connection breaker floor.
# Successive cancel_and_restart attempts cannot occur within 120 min on the
# same connection (breaker = 2h + ~5-15 min Lambda cron jitter = 125-135 min
# minimum observed gap in 7-day audit log). A 240-min window comfortably
# clears that floor and captures the natural ESCALATE-cluster duration
# (3-5 attempts over 4-5 hours per incident cluster).
KIND_BOUNCE_REPEAT_WINDOW_MIN = int(os.environ.get("KIND_BOUNCE_REPEAT_WINDOW_MIN", "240"))
GLOBAL_KIND_BOUNCE_KEY = "_GLOBAL_KIND_BOUNCE"

KIND_BOUNCE_PAYLOAD_TEMPLATE_PATH = (
    Path(__file__).parent / "ssm-payloads" / "kind_bounce.json.tmpl"
)

# v1 freeze-evidence collector (capture-then-remediate). Append-only fact capture
# that runs BEFORE any remediation touches the cluster, so it never removes the
# safety net. Hard-gated so it can never delay or block the actor.
CAPTURE_EVIDENCE_PAYLOAD_TEMPLATE_PATH = (
    Path(__file__).parent / "ssm-payloads" / "capture_evidence.json.tmpl"
)
CAPTURE_SSM_POLL_TIMEOUT_SECONDS = int(os.environ.get("CAPTURE_SSM_POLL_TIMEOUT_SECONDS", "30"))
# Total runtime the capture may consume; if the invocation has less budget than
# this, capture self-skips and remediation proceeds untouched.
CAPTURE_TOTAL_BUDGET_SECONDS = int(os.environ.get("CAPTURE_TOTAL_BUDGET_SECONDS", "45"))
SNOW_EVIDENCE_TABLE = "ad_analytics.ops.airbyte_freeze_evidence"


# ----------------------------------------------------------------------------
# Module-scoped boto3 clients (re-used across warm invocations)
# ----------------------------------------------------------------------------

ssm_client = boto3.client("ssm")
sns_client = boto3.client("sns")
secrets_client = boto3.client("secretsmanager")
ddb_client = boto3.client("dynamodb")
s3_client = boto3.client("s3")

# Wall-clock epoch by which the current invocation must finish (set per-invocation
# from Lambda context). None outside a Lambda invocation (e.g. unit tests), in
# which case _has_budget_for is a no-op that always returns True.
_INVOCATION_DEADLINE: float | None = None


def _has_budget_for(seconds: float) -> bool:
    """True if the current invocation has at least `seconds` of runtime budget
    left before the Lambda hard timeout. Returns True when the deadline is
    unknown (direct/unit-test calls)."""
    if _INVOCATION_DEADLINE is None:
        return True
    return (_INVOCATION_DEADLINE - time.time()) >= seconds


# ----------------------------------------------------------------------------
# Lambda entry point
# ----------------------------------------------------------------------------

def handler(event, context):
    """EventBridge invokes this every 15 min on cron(5,20,35,50)."""
    global _INVOCATION_DEADLINE
    _INVOCATION_DEADLINE = time.time() + (context.get_remaining_time_in_millis() / 1000.0)
    request_id = context.aws_request_id
    log_stream = context.log_stream_name
    LOGGER.info(json.dumps({"event": "invocation_start", "request_id": request_id}))

    observe_only = _read_observe_only_flag()
    LOGGER.info(json.dumps({"event": "flag_read", "observe_only": observe_only}))

    snowflake_conn = _open_snowflake_connection()
    try:
        _set_query_tag(snowflake_conn)
        breached = _detect_breaches(snowflake_conn)
        LOGGER.info(json.dumps({
            "event": "detection_done",
            "breached_connections": [b["CONNECTION_ID"] for b in breached],
        }))

        if not breached:
            LOGGER.info(json.dumps({"event": "ok_no_action", "request_id": request_id}))
            return {"status": "ok", "breached_count": 0}

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(
                    _process_connection,
                    snowflake_conn=snowflake_conn,
                    breach=b,
                    observe_only=observe_only,
                    request_id=request_id,
                    log_stream=log_stream,
                ): b["CONNECTION_ID"]
                for b in breached
            }
            for f in as_completed(futures):
                conn_id = futures[f]
                try:
                    f.result()
                except Exception as exc:
                    LOGGER.exception(json.dumps({
                        "event": "connection_processing_failed",
                        "connection_id": conn_id,
                        "error": str(exc),
                    }))
                    _emergency_escalate(conn_id, str(exc), request_id)

        return {"status": "ok", "breached_count": len(breached)}
    finally:
        snowflake_conn.close()


# ----------------------------------------------------------------------------
# Step 1: flags & state
# ----------------------------------------------------------------------------

def _read_observe_only_flag() -> bool:
    resp = ssm_client.get_parameter(Name=OBSERVE_ONLY_PARAM, WithDecryption=False)
    return resp["Parameter"]["Value"].strip().lower() == "true"


def _open_snowflake_connection():
    """Authenticate as SVC_DBT via key-pair from Secrets Manager.

    Mirrors the ECS task pattern: account/user/role/warehouse come from env
    vars; only the private key + passphrase come from Secrets Manager. The
    secret stores keys `SNOWFLAKE_PRIVATE_KEY` and
    `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.
    """
    sec = json.loads(secrets_client.get_secret_value(SecretId=SECRET_SNOWFLAKE)["SecretString"])
    private_key = _load_private_key(
        sec["SNOWFLAKE_PRIVATE_KEY"],
        sec.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE"),
    )
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key=private_key,
        role=os.environ.get("SNOWFLAKE_ROLE", "transformer_role"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "etl_wh"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "ad_analytics"),
        schema="ops",
    )


def _load_private_key(pem: str, passphrase: str | None) -> bytes:
    """Snowflake-connector wants DER-encoded PKCS8 bytes."""
    pem_bytes = pem.encode() if isinstance(pem, str) else pem
    pwd = passphrase.encode() if passphrase else None
    pk = serialization.load_pem_private_key(pem_bytes, password=pwd, backend=default_backend())
    return pk.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def _set_query_tag(conn) -> None:
    conn.cursor().execute("alter session set query_tag = 'lambda:airbyte_auto_remediate'")


# ----------------------------------------------------------------------------
# Step 2: detect
# ----------------------------------------------------------------------------

def _detect_breaches(conn) -> list[dict]:
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(f"""
        select
            connection_id,
            staleness_min,
            newest_extracted_at,
            warn_minutes,
            alert_minutes,
            status
        from {SNOW_FRESHNESS_VIEW}
        where status = 'ALERT'
        order by connection_id
    """)
    return list(cur.fetchall())


# ----------------------------------------------------------------------------
# Step 2.5: freeze-evidence capture (v1 collector) — capture BEFORE remediate
# ----------------------------------------------------------------------------

def _parse_kv(output: str) -> dict:
    """Lift all KEY=VALUE lines out of SSM stdout (first '=' splits). The capture
    payload emits scalar markers and KEY_JSON=<compact json> blobs; JSON values
    contain no '=' (projected to reason/timestamp/name fields only)."""
    kv = {}
    for line in output.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            kv[key.strip()] = value.strip()
    return kv


def _write_evidence_row(conn, row: dict) -> bool:
    """Append-only INSERT into the freeze-evidence table. JSON blobs go through
    PARSE_JSON; absent scalars/blobs stay NULL. Fully swallows errors (best-effort)
    so a persistence failure can never affect remediation. Returns True iff the row
    actually landed — the caller folds this into the capture metric so a
    write-vs-read regression is immediately visible."""
    json_cols = {
        "attempt_json": "attempt",
        "k8s_events_json": "k8s_events",
        "pods_json": "pods",
        "node_conditions_json": "node_conditions",
    }
    scalar_cols = ["event_id", "connection_id", "job_id", "capture_status", "capture_detail"]

    cols, selects, params = [], [], {}
    for c in scalar_cols:
        if row.get(c) is not None:
            cols.append(c)
            selects.append(f"%({c})s")
            params[c] = row[c]
    for src, col in json_cols.items():
        if row.get(src):
            cols.append(col)
            selects.append(f"parse_json(%({src})s)")
            params[src] = row[src]

    sql = f"insert into {SNOW_EVIDENCE_TABLE} ({', '.join(cols)}) select {', '.join(selects)}"
    try:
        conn.cursor().execute(sql, params)
        return True
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "evidence_write_failed",
            "event_id": row.get("event_id"),
            "error": str(exc)[:300],
        }))
        return False


def _emit_capture_metric(conn_id: str, outcome: str, start_ts: float,
                         persisted: bool | None = None) -> None:
    """One structured metric line per capture attempt, on EVERY exit path, so
    COLLECTOR health is queryable in CloudWatch Logs Insights at zero
    PutMetricData cost. Two ORTHOGONAL fields keep capture-vs-persist explicit:
      * outcome   — the CAPTURE result (ok / partial / empty / skipped_budget /
                    ssm_send_failed / ssm_poll_error / ssm_poll_timeout);
      * persisted — did the row actually LAND in Snowflake (true / false, or null
                    when no write was attempted).
    A capture is a TRUE success only when persisted is true. A read that succeeds
    but fails to persist logs outcome='ok', persisted=false — so a write
    regression surfaces immediately instead of hiding behind 'ok'. Insights
    'succeeded' = count(persisted=1); real failures = persisted=0 AND
    outcome != 'skipped_budget'."""
    LOGGER.info(json.dumps({
        "event": "capture_metric",
        "connection_id": conn_id,
        "outcome": outcome,
        "persisted": persisted,
        "duration_ms": int((time.time() - start_ts) * 1000),
    }))


def _capture_evidence(snowflake_conn, conn_id: str, event_id: str) -> dict | None:
    """v1 freeze-evidence collector — capture an unbiased, fact-only evidence
    bundle BEFORE any remediation touches the cluster, then persist it append-only.

    Sole objective: let a later query answer "what is the first authoritative
    abnormal event that consistently precedes an organic freeze?" It assumes
    NOTHING about the root cause — it records the master datum (recent pods +
    phase/terminated), the self-timestamped k8s Warning events (sorted ASC — the
    FAE bearer), the Airbyte attempt onset anchor, and node conditions, for all
    hypotheses equally. It records facts only; hypothesis elimination happens in
    analysis, never here.

    HARD CONTRACT — must NEVER delay or block remediation:
      * budget-gated: self-skips when the invocation lacks CAPTURE_TOTAL_BUDGET;
      * hard-timeout-capped SSM poll (CAPTURE_SSM_POLL_TIMEOUT_SECONDS);
      * EVERY failure mode writes a capture_status marker + a metric and returns.
    The call site also wraps this in try/except, so an exception here is inert.

    IDENTITY: event_id (fresh UUID per invocation) is the row PK and identifies
    this SNAPSHOT. job_id (the frozen Airbyte job) identifies the FREEZE — many
    snapshots of one ongoing freeze share job_id, so analysis groups by job_id to
    build per-freeze timelines and to count DISTINCT freezes for the >=4/5 bar.

    ROLLBACK: set env var CAPTURE_ENABLED=false to disable the collector in ~30s
    (aws lambda update-function-configuration) with no redeploy; remediation is
    unaffected either way.

    RETURNS: the parsed Airbyte attempt dict when the capture succeeded, else None.
    The progress gate consumes this; every failure path returns None, which the
    gate treats as "cannot prove progress" and falls back to acting — so the
    "must never block remediation" contract above is preserved unchanged.
    """
    if os.environ.get("CAPTURE_ENABLED", "true").strip().lower() != "true":
        return None

    start_ts = time.time()

    if not _has_budget_for(CAPTURE_TOTAL_BUDGET_SECONDS):
        _emit_capture_metric(conn_id, "skipped_budget", start_ts, persisted=False)
        return None

    try:
        template = CAPTURE_EVIDENCE_PAYLOAD_TEMPLATE_PATH.read_text()
        payload = json.loads(template.replace("__CONNECTION_ID__", AIRBYTE_CONNECTION_IDS[conn_id]))
        send_resp = ssm_client.send_command(
            InstanceIds=[AIRBYTE_INSTANCE_ID],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": payload["commands"]},
            TimeoutSeconds=CAPTURE_SSM_POLL_TIMEOUT_SECONDS,
        )
    except Exception as exc:
        persisted = _write_evidence_row(snowflake_conn, {
            "event_id": event_id, "connection_id": conn_id,
            "capture_status": "ssm_send_failed", "capture_detail": str(exc)[:500],
        })
        _emit_capture_metric(conn_id, "ssm_send_failed", start_ts, persisted=persisted)
        return None

    command_id = send_resp["Command"]["CommandId"]
    try:
        inv = _poll_ssm_invocation(command_id, time.time() + CAPTURE_SSM_POLL_TIMEOUT_SECONDS)
    except Exception as exc:
        persisted = _write_evidence_row(snowflake_conn, {
            "event_id": event_id, "connection_id": conn_id,
            "capture_status": "ssm_poll_error", "capture_detail": str(exc)[:500],
        })
        _emit_capture_metric(conn_id, "ssm_poll_error", start_ts, persisted=persisted)
        return None

    if inv is None or inv.get("Status") not in _SSM_TERMINAL_STATUSES:
        persisted = _write_evidence_row(snowflake_conn, {
            "event_id": event_id, "connection_id": conn_id,
            "capture_status": "ssm_poll_timeout",
        })
        _emit_capture_metric(conn_id, "ssm_poll_timeout", start_ts, persisted=persisted)
        return None

    output = inv.get("StandardOutputContent", "") or ""
    kv = _parse_kv(output)
    if not output:
        status, detail = "empty", f"ssm_status={inv.get('Status')}"
    elif kv.get("CAPTURE_DONE") == "1" and "CAPTURE_TOKEN_FAILED" not in output:
        status, detail = "ok", None
    else:
        status, detail = "partial", f"ssm_status={inv.get('Status')}"

    job_id = None
    attempt = None
    try:
        attempt = json.loads(kv.get("ATTEMPT_JSON") or "{}")
        job_id = (str(attempt.get("jobId") or attempt.get("id") or "").strip() or None)
    except Exception:
        job_id = None
        attempt = None

    persisted = _write_evidence_row(snowflake_conn, {
        "event_id": event_id,
        "connection_id": conn_id,
        "job_id": job_id,
        "capture_status": status,
        "capture_detail": detail,
        "attempt_json": kv.get("ATTEMPT_JSON"),
        "k8s_events_json": kv.get("K8S_EVENTS_JSON"),
        "pods_json": kv.get("PODS_JSON"),
        "node_conditions_json": kv.get("NODE_CONDITIONS_JSON"),
    })
    _emit_capture_metric(conn_id, status, start_ts, persisted=persisted)
    return attempt if isinstance(attempt, dict) and attempt else None


# ----------------------------------------------------------------------------
# Progress gate: distinguish "stuck" from "slow but progressing"
# ----------------------------------------------------------------------------

PROGRESS_GATE_ENABLED = os.environ.get("PROGRESS_GATE_ENABLED", "true").strip().lower() == "true"
PROGRESS_OBS_TTL_SECONDS = int(os.environ.get("PROGRESS_OBS_TTL_SECONDS", "21600"))  # 6h
_PROGRESS_KEY_PREFIX = "progress#"
# Airbyte job states that mean "a job is alive right now and could still commit".
_LIVE_JOB_STATUSES = {"running", "pending", "incomplete"}


def _progress_key(conn_id: str) -> str:
    """Namespaced DDB key.

    MUST stay distinct from the bare connection_id used by the circuit breaker:
    _open_breaker writes with put_item, which REPLACES the whole item. Sharing a
    key would silently clobber breaker_until and disable the breaker.
    """
    return f"{_PROGRESS_KEY_PREFIX}{conn_id}"


def _read_progress_observation(conn_id: str) -> dict | None:
    try:
        resp = ddb_client.get_item(
            TableName=DDB_TABLE,
            Key={"connection_id": {"S": _progress_key(conn_id)}},
            ConsistentRead=True,
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "progress_read_failure", "connection_id": conn_id, "error": str(exc),
        }))
        return None

    item = resp.get("Item")
    if not item:
        return None
    try:
        return {
            "job_id": item.get("job_id", {}).get("S") or None,
            "bytes_synced": int(item.get("bytes_synced", {}).get("N", "0")),
            "rows_synced": int(item.get("rows_synced", {}).get("N", "0")),
            "observed_at": int(item.get("observed_at", {}).get("N", "0")),
        }
    except Exception:
        return None


def _write_progress_observation(conn_id: str, job_id: str | None,
                                bytes_synced: int, rows_synced: int) -> None:
    now_epoch = int(time.time())
    try:
        ddb_client.put_item(
            TableName=DDB_TABLE,
            Item={
                "connection_id": {"S": _progress_key(conn_id)},
                "job_id": {"S": str(job_id or "")},
                "bytes_synced": {"N": str(int(bytes_synced))},
                "rows_synced": {"N": str(int(rows_synced))},
                "observed_at": {"N": str(now_epoch)},
                "ttl": {"N": str(now_epoch + PROGRESS_OBS_TTL_SECONDS)},
            },
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "progress_write_failure", "connection_id": conn_id, "error": str(exc),
        }))


def _evaluate_progress_gate(conn_id: str, attempt: dict | None) -> tuple[str, str]:
    """Decide whether cancel+restart is safe. Returns (decision, reason).

    WHY THIS EXISTS (2026-07-22 incident): staleness alone cannot tell "frozen"
    from "slow but committing". On 2026-07-22 Magento was draining a backlog —
    every sync WAS moving data, just slower than the 30-min threshold — and this
    Lambda cancelled it four times. Each cancel discarded real work (job 28578 lost
    1h21m) and the restart re-read the binlog from the last committed offset, so
    the connection could never catch up. The remediation became the outage.

    Decisions:
      ACT                -> cancel+restart is appropriate (frozen, or unprovable)
      SKIP_PROGRESSING   -> a live job is committing; leave it alone
      SKIP_NEED_BASELINE -> data is moving but there is no prior sample to compare;
                            record one and re-evaluate next invocation (~15 min)

    Bias: only SKIP when there is positive evidence of movement. Absent or
    unparseable evidence always falls through to ACT, preserving prior behaviour.
    """
    if not PROGRESS_GATE_ENABLED:
        return "ACT", "gate_disabled"

    if not isinstance(attempt, dict) or not attempt:
        return "ACT", "no_attempt_evidence"

    status = str(attempt.get("status") or "").strip().lower()
    job_id = str(attempt.get("jobId") or attempt.get("id") or "").strip() or None

    try:
        bytes_synced = int(attempt.get("bytesSynced") or 0)
        rows_synced = int(attempt.get("rowsSynced") or 0)
    except (TypeError, ValueError):
        return "ACT", "unparseable_counters"

    # No live job => nothing to protect; the classic freeze also lands here once
    # the stuck job has been reaped.
    if status not in _LIVE_JOB_STATUSES:
        return "ACT", f"job_not_live:{status or 'unknown'}"

    # Canonical freeze signature (2026-05-03): a live job that has moved nothing.
    # Act immediately — do NOT spend a cycle collecting a baseline for this case.
    if bytes_synced == 0 and rows_synced == 0:
        return "ACT", "zero_progress_live_job"

    previous = _read_progress_observation(conn_id)
    _write_progress_observation(conn_id, job_id, bytes_synced, rows_synced)

    if previous is None or previous.get("job_id") != (job_id or ""):
        # Different job (or first sighting): counters are not comparable across
        # jobs, since each job restarts them at zero.
        return "SKIP_NEED_BASELINE", "no_comparable_prior_sample"

    if bytes_synced > previous["bytes_synced"] or rows_synced > previous["rows_synced"]:
        delta_b = bytes_synced - previous["bytes_synced"]
        delta_r = rows_synced - previous["rows_synced"]
        return "SKIP_PROGRESSING", f"advanced_bytes={delta_b},rows={delta_r}"

    return "ACT", "counters_flat_between_samples"


# ----------------------------------------------------------------------------
# Step 3: per-connection processing
# ----------------------------------------------------------------------------

def _process_connection(snowflake_conn, breach, observe_only, request_id, log_stream):
    conn_id = breach["CONNECTION_ID"]
    pre_staleness = int(breach["STALENESS_MIN"])
    incident_started_at = breach.get("NEWEST_EXTRACTED_AT")

    base_audit = {
        "event_id": str(uuid.uuid4()),
        "incident_started_at": incident_started_at,
        "connection_id": conn_id,
        "tier": "ALERT",
        "pre_staleness_min": pre_staleness,
        "lambda_request_id": request_id,
        "lambda_log_stream": log_stream,
    }

    # Capture-then-remediate: snapshot the freeze evidence BEFORE any tier acts,
    # so protection is never disabled. Double-wrapped + budget-gated internally so
    # a capture fault can never delay, block, or fail remediation.
    attempt_evidence = None
    try:
        attempt_evidence = _capture_evidence(snowflake_conn, conn_id, base_audit["event_id"])
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "capture_evidence_uncaught",
            "connection_id": conn_id,
            "error": str(exc),
        }))

    breaker_until = _check_breaker(conn_id)
    if breaker_until is not None:
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "outcome": "BREAKER_OPEN",
            "breaker_until_at": breaker_until,
        })
        LOGGER.info(json.dumps({
            "event": "skipped_breaker_open",
            "connection_id": conn_id,
            "breaker_until": breaker_until.isoformat(),
        }))
        return

    # Progress gate — must run BEFORE the observe-only branch so that a soak in
    # observe-only mode exercises (and reports on) the real decision, instead of
    # reporting "would cancel" for drains the gate would actually have spared.
    gate_decision, gate_reason = _evaluate_progress_gate(conn_id, attempt_evidence)
    if gate_decision != "ACT":
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "outcome": "SKIPPED_PROGRESSING",
            "action_taken": "none",
            "failure_reason": f"{gate_decision}:{gate_reason}"[:500],
        })
        LOGGER.info(json.dumps({
            "event": "skipped_progress_gate",
            "connection_id": conn_id,
            "decision": gate_decision,
            "reason": gate_reason,
            "pre_staleness_min": pre_staleness,
        }))
        return

    if observe_only:
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "outcome": "OBSERVE_ONLY_WOULD_ACT",
            "action_taken": "would_cancel_and_restart",
        })
        _publish_sns(
            f"[Airbyte OBSERVE] {conn_id} would-act @ {pre_staleness}m",
            _build_observe_email(conn_id, pre_staleness, breach),
        )
        _post_clickup_comment(_build_clickup_observe_comment(conn_id, pre_staleness))
        return

    restart_command_time = datetime.now(timezone.utc)
    cancelled_job, restart_job, ssm_failure = _ssm_cancel_and_restart(conn_id)

    if ssm_failure:
        breaker_dt = _open_breaker(conn_id)
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "cancel_and_restart",
            "outcome": "ESCALATE",
            "failure_reason": ssm_failure[:500],
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "verification_method": None,
            "breaker_until_at": breaker_dt,
        })
        _publish_sns(
            f"[Airbyte ESCALATE] {conn_id} restart failed",
            _build_escalate_email(conn_id, pre_staleness, ssm_failure, cancelled_job, restart_job),
        )
        _post_clickup_comment(
            _build_clickup_escalate_comment(conn_id, pre_staleness, ssm_failure, cancelled_job, restart_job)
        )
        return

    LOGGER.info(json.dumps({
        "event": "sleeping_for_verification",
        "connection_id": conn_id,
        "wait_seconds": VERIFY_WAIT_SECONDS,
    }))
    time.sleep(VERIFY_WAIT_SECONDS)

    post_staleness, verification_method = _verify_recovery(
        snowflake_conn, conn_id, pre_staleness, restart_command_time
    )

    if verification_method == "both_inconclusive_escalated":
        bounce_decision, bounce_skip_reason, trigger_reason = _evaluate_kind_bounce_eligibility(
            snowflake_conn=snowflake_conn,
            conn_id=conn_id,
            post_staleness=post_staleness,
        )

        if bounce_decision == "TRIGGER":
            _execute_kind_bounce_tier(
                snowflake_conn=snowflake_conn,
                conn_id=conn_id,
                base_audit=base_audit,
                pre_staleness=pre_staleness,
                post_cancel_restart_staleness=post_staleness,
                cancelled_job=cancelled_job,
                restart_job=restart_job,
                trigger_reason=trigger_reason,
            )
            return

        if bounce_decision == "OBSERVE":
            # Intentional dual-write: an OBSERVE decision means Tier 1 still
            # escalates AND we surface what Tier 2 would have done. Operator
            # gets two audit rows + two notifications for the same incident
            # so they can validate the would-act decision against the actual
            # restart outcome during soak. Squashing into one row would lose
            # the trigger-eligibility signal.
            _write_audit_row(snowflake_conn, {
                **base_audit,
                "action_taken": "would_kind_bounce",
                "outcome": "OBSERVE_ONLY_WOULD_ACT",
                "post_staleness_min": post_staleness,
                "verification_method": verification_method,
                "failure_reason": (
                    f"trigger:{trigger_reason}" if trigger_reason else None
                ),
            })
            _publish_sns(
                f"[Airbyte KIND-BOUNCE OBSERVE] {conn_id} would bounce @ {post_staleness}m ({trigger_reason})",
                _build_kind_bounce_observe_email(
                    conn_id, pre_staleness, post_staleness, trigger_reason
                ),
            )
            _post_clickup_comment(
                _build_clickup_kind_bounce_observe_comment(
                    conn_id, pre_staleness, post_staleness, trigger_reason
                )
            )

        failure_reason = bounce_skip_reason or "restart_did_not_recover"
        breaker_dt = _open_breaker(conn_id)
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "cancel_and_restart",
            "outcome": "ESCALATE",
            "failure_reason": failure_reason,
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_staleness,
            "verification_method": verification_method,
            "breaker_until_at": breaker_dt,
        })
        _publish_sns(
            f"[Airbyte ESCALATE] {conn_id} did not recover ({post_staleness}m post-restart)",
            _build_escalate_email(conn_id, pre_staleness, failure_reason,
                                  cancelled_job, restart_job, post_staleness),
        )
        _post_clickup_comment(_build_clickup_escalate_comment(
            conn_id, pre_staleness, failure_reason,
            cancelled_job, restart_job, post_staleness,
        ))
    else:
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "cancel_and_restart",
            "outcome": "AUTO_FIX",
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_staleness,
            "verification_method": verification_method,
        })
        _publish_sns(
            f"[Airbyte AUTO-FIX] {conn_id} recovered ({pre_staleness}m → {post_staleness}m)",
            _build_autofix_email(conn_id, pre_staleness, post_staleness, cancelled_job, restart_job),
        )
        _post_clickup_comment(_build_clickup_autofix_comment(
            conn_id, pre_staleness, post_staleness, cancelled_job, restart_job,
        ))


# ----------------------------------------------------------------------------
# Step 3 helpers: SSM cancel + restart
# ----------------------------------------------------------------------------

def _poll_ssm_invocation(command_id: str, deadline: float) -> dict | None:
    """Poll get_command_invocation until a terminal status or `deadline`.

    Returns the last invocation dict seen — terminal, or (on timeout) the last
    non-terminal snapshot — or None if the invocation never registered. Callers
    check inv["Status"] against _SSM_TERMINAL_STATUSES to distinguish a confirmed
    result from a poll timeout.
    """
    inv = None
    while time.time() < deadline:
        time.sleep(SSM_POLL_INTERVAL_SECONDS)
        try:
            inv = ssm_client.get_command_invocation(
                CommandId=command_id, InstanceId=AIRBYTE_INSTANCE_ID
            )
        except ssm_client.exceptions.InvocationDoesNotExist:
            continue
        if inv["Status"] in _SSM_TERMINAL_STATUSES:
            break
    return inv


def _ssm_cancel_and_restart(
    conn_id: str, poll_timeout_seconds: int = SSM_POLL_TIMEOUT_SECONDS
) -> tuple[str | None, str | None, str | None]:
    """Returns (cancelled_job_id, restart_job_id, failure_reason).

    failure_reason is None on success. `poll_timeout_seconds` caps how long we
    wait for the command to reach a terminal status; callers whose result is
    non-fatal (e.g. the post-bounce fresh-sync kick) pass a short value.
    """
    template = SSM_PAYLOAD_TEMPLATE_PATH.read_text()
    payload_str = template.replace("__CONNECTION_ID__", AIRBYTE_CONNECTION_IDS[conn_id])
    payload = json.loads(payload_str)

    try:
        send_resp = ssm_client.send_command(
            InstanceIds=[AIRBYTE_INSTANCE_ID],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": payload["commands"]},
            TimeoutSeconds=SSM_POLL_TIMEOUT_SECONDS,
        )
    except Exception as exc:
        return None, None, f"ssm_send_command_exception: {exc}"

    command_id = send_resp["Command"]["CommandId"]
    LOGGER.info(json.dumps({"event": "ssm_command_sent", "connection_id": conn_id, "command_id": command_id}))

    inv = _poll_ssm_invocation(command_id, time.time() + poll_timeout_seconds)
    if inv is None or inv.get("Status") not in _SSM_TERMINAL_STATUSES:
        return None, None, "ssm_poll_deadline_exceeded"

    if inv["Status"] != "Success":
        stderr = (inv.get("StandardErrorContent") or "")[:400]
        stdout = (inv.get("StandardOutputContent") or "")[:200]
        return None, None, f"ssm_command_status={inv['Status']}; stderr={stderr}; stdout={stdout}"

    output = inv.get("StandardOutputContent", "") or ""
    cancelled_job = _extract_var(output, "CANCEL_JOB_ID")
    restart_job = _extract_var(output, "RESTART_JOB_ID")

    if not restart_job:
        return cancelled_job, None, f"restart_job_id_missing_from_output: {output[:300]}"
    if "RESTART_OK" not in output:
        return cancelled_job, restart_job, f"restart_marker_missing: {output[:300]}"

    return cancelled_job, restart_job, None


def _extract_var(output: str, var_name: str) -> str | None:
    """Lift `VAR=value` lines out of SSM stdout."""
    prefix = f"{var_name}="
    for line in output.splitlines():
        line = line.strip()
        if line.startswith(prefix):
            v = line[len(prefix):].strip()
            return v if v else None
    return None


# ----------------------------------------------------------------------------
# Step 3 helpers: verification (Snowflake re-query primary, S3 LIST fallback)
# ----------------------------------------------------------------------------

def _verify_recovery(conn, conn_id: str, pre_staleness: int,
                     restart_time: datetime) -> tuple[int, str]:
    """Returns (post_staleness_min, verification_method).

    verification_method:
      - 'snowflake_view_refreshed'      — Snowflake view shows fresh data
      - 's3_list_recent_fallback'       — Snowflake didn't refresh; S3 has new files
      - 'both_inconclusive_escalated'   — neither shows recovery
    """
    snow_post = _query_post_staleness(conn, conn_id)
    if snow_post is not None and snow_post < pre_staleness:
        LOGGER.info(json.dumps({
            "event": "verify_via_snowflake_ok",
            "connection_id": conn_id,
            "pre_min": pre_staleness, "post_min": snow_post,
        }))
        return snow_post, "snowflake_view_refreshed"

    s3_recovered, newest_modified = _verify_via_s3_listing(conn_id, restart_time)
    if s3_recovered:
        LOGGER.info(json.dumps({
            "event": "verify_via_s3_ok",
            "connection_id": conn_id,
            "newest_s3_modified": newest_modified.isoformat() if newest_modified else None,
            "snow_post_unrefreshed": snow_post,
        }))
        return 0 if snow_post is None else min(snow_post, 5), "s3_list_recent_fallback"

    LOGGER.warning(json.dumps({
        "event": "verify_inconclusive",
        "connection_id": conn_id,
        "snow_post": snow_post,
        "s3_recovered": s3_recovered,
    }))
    return snow_post if snow_post is not None else pre_staleness, "both_inconclusive_escalated"


def _query_post_staleness(conn, conn_id: str) -> int | None:
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute(f"""
        select staleness_min
        from {SNOW_FRESHNESS_VIEW}
        where connection_id = %(conn_id)s
    """, {"conn_id": conn_id})
    rows = cur.fetchall()
    if not rows:
        return None
    val = rows[0].get("STALENESS_MIN")
    return int(val) if val is not None else None


def _verify_via_s3_listing(conn_id: str, restart_time: datetime) -> tuple[bool, datetime | None]:
    """LIST the canary table's data prefix; return True if any object's
    LastModified is after restart_time."""
    canary = S3_CANARY_TABLES[conn_id]
    prefix = f"{S3_PREFIXES[conn_id]}{canary}/data/"
    try:
        resp = s3_client.list_objects_v2(
            Bucket=LAKEHOUSE_BUCKET,
            Prefix=prefix,
            MaxKeys=20,
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({"event": "s3_list_failure", "connection_id": conn_id, "error": str(exc)}))
        return False, None

    contents = resp.get("Contents", [])
    if not contents:
        return False, None

    newest = max(contents, key=lambda o: o["LastModified"])
    return newest["LastModified"] > restart_time, newest["LastModified"]


# ----------------------------------------------------------------------------
# Step 3 helpers: Tier 2 — kind-bounce (control-plane restart)
# ----------------------------------------------------------------------------

def _read_kind_bounce_observe_only_flag() -> bool:
    try:
        resp = ssm_client.get_parameter(
            Name=KIND_BOUNCE_OBSERVE_ONLY_PARAM, WithDecryption=False
        )
        return resp["Parameter"]["Value"].strip().lower() == "true"
    except ssm_client.exceptions.ParameterNotFound:
        LOGGER.warning(json.dumps({
            "event": "kind_bounce_observe_only_param_missing",
            "param": KIND_BOUNCE_OBSERVE_ONLY_PARAM,
            "defaulting_to": True,
        }))
        return True


def _other_connection_actively_syncing(conn_id_to_bounce: str) -> bool:
    others = [c for c in AIRBYTE_CONNECTION_IDS if c != conn_id_to_bounce]
    if not others:
        return False
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=VERIFY_WAIT_SECONDS)
    for other_conn in others:
        canary = S3_CANARY_TABLES[other_conn]
        prefix = f"{S3_PREFIXES[other_conn]}{canary}/data/"
        try:
            resp = s3_client.list_objects_v2(
                Bucket=LAKEHOUSE_BUCKET, Prefix=prefix, MaxKeys=20
            )
        except Exception as exc:
            LOGGER.warning(json.dumps({
                "event": "concurrent_sync_check_failure",
                "other_conn": other_conn,
                "error": str(exc),
            }))
            continue
        contents = resp.get("Contents", [])
        if not contents:
            continue
        newest = max(contents, key=lambda o: o["LastModified"])
        if newest["LastModified"] > cutoff:
            return True
    return False


def _check_global_kind_bounce_cooldown() -> datetime | None:
    return _check_breaker(GLOBAL_KIND_BOUNCE_KEY)


def _open_global_kind_bounce_cooldown() -> datetime:
    breaker_until_epoch = int(time.time()) + KIND_BOUNCE_COOLDOWN_SECONDS
    breaker_until_dt = datetime.fromtimestamp(breaker_until_epoch, tz=timezone.utc)
    try:
        ddb_client.put_item(
            TableName=DDB_TABLE,
            Item={
                "connection_id": {"S": GLOBAL_KIND_BOUNCE_KEY},
                "breaker_until": {"N": str(breaker_until_epoch)},
                "last_attempt_at": {"N": str(int(time.time()))},
                "ttl": {"N": str(breaker_until_epoch + 60)},
            },
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "global_kind_bounce_cooldown_write_failure",
            "error": str(exc),
        }))
    return breaker_until_dt


def _count_recent_cancel_restarts(snowflake_conn, conn_id: str) -> int:
    """Count prior `cancel_and_restart` attempts on this connection in the
    last KIND_BOUNCE_REPEAT_WINDOW_MIN minutes. Excludes the current attempt
    (called before its audit row is written). Returns 0 on query failure
    (fail open — don't block a real trigger because of a query glitch)."""
    try:
        cur = snowflake_conn.cursor(snowflake.connector.DictCursor)
        cur.execute(f"""
            select count(*) as n
            from {SNOW_AUDIT_TABLE}
            where connection_id = %(conn_id)s
              and action_taken = 'cancel_and_restart'
              and event_time >= dateadd(minute, %(window)s, current_timestamp())
        """, {"conn_id": conn_id, "window": -KIND_BOUNCE_REPEAT_WINDOW_MIN})
        rows = cur.fetchall()
        return int(rows[0]["N"]) if rows else 0
    except Exception as exc:
        LOGGER.warning(json.dumps({
            "event": "repeat_count_query_failure",
            "connection_id": conn_id,
            "error": str(exc),
        }))
        return 0


def _evaluate_kind_bounce_eligibility(
    snowflake_conn, conn_id: str, post_staleness: int | None
) -> tuple[str, str | None, str | None]:
    """Returns (decision, skip_reason, trigger_reason).

    decision ∈ {'TRIGGER', 'OBSERVE', 'SKIP'}
    skip_reason populated only when the SKIP is due to a Tier 2 gate
    (cooldown / concurrent sync); a plain "neither trigger fired" returns
    (SKIP, None, None) so the caller falls through to existing ESCALATE wording.
    trigger_reason ∈ {'deep_stuck', 'repeat_pattern', None} — propagated to
    audit log and notifications.

    Two trigger paths:
      1. deep_stuck:    post_staleness > KIND_BOUNCE_TRIGGER_POST_MIN (60 min)
      2. repeat_pattern: prior cancel+restart count in last
         KIND_BOUNCE_REPEAT_WINDOW_MIN minutes is >= KIND_BOUNCE_REPEAT_COUNT - 1
         (i.e., this attempt makes the N-th in the window)
    """
    if post_staleness is None:
        return ("SKIP", None, None)

    deep_stuck = post_staleness > KIND_BOUNCE_TRIGGER_POST_MIN

    repeat_pattern = False
    repeat_count = 0
    if not deep_stuck:
        repeat_count = _count_recent_cancel_restarts(snowflake_conn, conn_id)
        repeat_pattern = repeat_count >= (KIND_BOUNCE_REPEAT_COUNT - 1)

    if not (deep_stuck or repeat_pattern):
        return ("SKIP", None, None)

    trigger_reason = "deep_stuck" if deep_stuck else "repeat_pattern"

    cooldown_until = _check_global_kind_bounce_cooldown()
    if cooldown_until is not None:
        LOGGER.info(json.dumps({
            "event": "kind_bounce_skipped_cooldown",
            "connection_id": conn_id,
            "trigger_reason": trigger_reason,
            "cooldown_until": cooldown_until.isoformat(),
        }))
        return ("SKIP", "kind_bounce_cooldown_open", trigger_reason)

    if _other_connection_actively_syncing(conn_id):
        LOGGER.info(json.dumps({
            "event": "kind_bounce_skipped_concurrent_sync",
            "connection_id": conn_id,
            "trigger_reason": trigger_reason,
        }))
        return ("SKIP", "kind_bounce_skipped_concurrent_sync", trigger_reason)

    if _read_kind_bounce_observe_only_flag():
        LOGGER.info(json.dumps({
            "event": "kind_bounce_observe_only_decision",
            "connection_id": conn_id,
            "post_staleness_min": post_staleness,
            "trigger_reason": trigger_reason,
            "repeat_count_in_window": repeat_count,
        }))
        return ("OBSERVE", None, trigger_reason)

    LOGGER.info(json.dumps({
        "event": "kind_bounce_trigger",
        "connection_id": conn_id,
        "post_staleness_min": post_staleness,
        "trigger_reason": trigger_reason,
        "repeat_count_in_window": repeat_count,
    }))
    return ("TRIGGER", None, trigger_reason)


def _ssm_kind_bounce() -> tuple[str, str | None]:
    """Restart the Airbyte control-plane container via SSM.

    Returns (status, detail):
      - (KIND_BOUNCE_SSM_SUCCESS, None)    command finished and the control plane
                                           came back healthy (READINESS_OK).
      - (KIND_BOUNCE_SSM_FAILED, reason)   command reached a terminal non-Success
                                           status, or Success without READINESS_OK
                                           (control plane did not become healthy)
                                           — a CONFIRMED failure.
      - (KIND_BOUNCE_SSM_UNKNOWN, reason)  no terminal status even after
                                           reconciliation — the bounce may or may
                                           not have run. Caller must NOT treat
                                           this as a hard failure (in particular,
                                           must NOT open the global cooldown).

    The control-plane restart legitimately runs longer than the 120s primary
    poll window (the payload waits up to 120s for readiness plus SSM delivery
    latency), so a primary-poll timeout is RECONCILED by continuing to poll for
    the command's true terminal status. Declaring failure at 120s (the old
    behavior) armed the 6h global cooldown and deadlocked remediation while the
    restart had actually succeeded.
    """
    payload = json.loads(KIND_BOUNCE_PAYLOAD_TEMPLATE_PATH.read_text())
    try:
        send_resp = ssm_client.send_command(
            InstanceIds=[AIRBYTE_INSTANCE_ID],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": payload["commands"]},
            TimeoutSeconds=KIND_BOUNCE_SSM_RECONCILE_SECONDS,
        )
    except Exception as exc:
        # Send never reached the instance — the control plane was NOT touched, so
        # there is no "already bounced, don't re-bounce" reason to arm the 6h
        # cooldown. Classify UNKNOWN (arms nothing) and let the next cycle retry;
        # this is a strictly stronger "nothing happened" than a reconcile timeout.
        return KIND_BOUNCE_SSM_UNKNOWN, f"ssm_send_command_exception: {exc}"

    command_id = send_resp["Command"]["CommandId"]
    LOGGER.info(json.dumps({"event": "kind_bounce_ssm_sent", "command_id": command_id}))

    # Phase 1: primary poll (same window as cancel+restart).
    inv = _poll_ssm_invocation(command_id, time.time() + SSM_POLL_TIMEOUT_SECONDS)

    # Phase 2: reconcile a still-running command rather than declaring failure.
    if inv is None or inv.get("Status") not in _SSM_TERMINAL_STATUSES:
        LOGGER.info(json.dumps({
            "event": "kind_bounce_ssm_reconciling",
            "command_id": command_id,
            "reconcile_deadline_s": KIND_BOUNCE_SSM_RECONCILE_SECONDS,
        }))
        inv = _poll_ssm_invocation(
            command_id,
            time.time() + max(0, KIND_BOUNCE_SSM_RECONCILE_SECONDS - SSM_POLL_TIMEOUT_SECONDS),
        )

    if inv is None or inv.get("Status") not in _SSM_TERMINAL_STATUSES:
        return KIND_BOUNCE_SSM_UNKNOWN, "ssm_poll_deadline_exceeded_unreconciled"

    status = inv["Status"]
    if status != "Success":
        stderr = (inv.get("StandardErrorContent") or "")[:400]
        stdout = (inv.get("StandardOutputContent") or "")[:200]
        return KIND_BOUNCE_SSM_FAILED, f"ssm_command_status={status}; stderr={stderr}; stdout={stdout}"

    output = inv.get("StandardOutputContent", "") or ""
    if "READINESS_OK" not in output:
        return KIND_BOUNCE_SSM_FAILED, f"readiness_marker_missing: {output[:300]}"
    return KIND_BOUNCE_SSM_SUCCESS, None


def _execute_kind_bounce_tier(
    snowflake_conn,
    conn_id: str,
    base_audit: dict,
    pre_staleness: int,
    post_cancel_restart_staleness: int,
    cancelled_job: str | None,
    restart_job: str | None,
    trigger_reason: str | None = None,
) -> None:
    bounce_command_time = datetime.now(timezone.utc)
    bounce_status, bounce_detail = _ssm_kind_bounce()
    trigger_tag = f"trigger:{trigger_reason}" if trigger_reason else "trigger:unknown"

    # Tier timing (cap-based): detect ~2s + Tier-1 cancel/restart poll ≤120s +
    # VERIFY_WAIT 300s + verify ~10s + eligibility ~5s + bounce reconcile ≤240s +
    # post-bounce cancel/restart poll ≤45s + KIND_BOUNCE verify 180s can reach
    # ~900s at the caps, so the 180s verify sleep below is gated by
    # _has_budget_for — an overrun defers verification instead of hard-killing.

    if bounce_status == KIND_BOUNCE_SSM_UNKNOWN:
        # Reconciliation could not confirm the command's terminal status, so we
        # cannot say the bounce failed. Do NOT open the global cooldown (arming
        # it on an unconfirmed timeout was the root cause of the deadlock) and do
        # NOT arm the per-connection breaker. Notify a human and let the next
        # invocation re-detect — the freshness check is the real verifier, and if
        # the bounce completed out-of-band the next cycle simply sees recovery.
        LOGGER.warning(json.dumps({
            "event": "kind_bounce_ssm_unknown",
            "connection_id": conn_id,
            "detail": bounce_detail,
        }))
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "kind_bounce",
            "outcome": "ESCALATE",
            "failure_reason": f"kind_bounce_ssm_unknown: {bounce_detail} ({trigger_tag})"[:500],
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_cancel_restart_staleness,
            "verification_method": "kind_bounce_ssm_unknown",
        })
        _publish_sns(
            f"[Airbyte KIND-BOUNCE UNKNOWN] {conn_id} bounce status unconfirmed ({trigger_reason})",
            _build_kind_bounce_unknown_email(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                bounce_detail, trigger_reason=trigger_reason,
            ),
        )
        _post_clickup_comment(
            _build_clickup_kind_bounce_unknown_comment(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                bounce_detail, trigger_reason=trigger_reason,
            )
        )
        return

    if bounce_status == KIND_BOUNCE_SSM_FAILED:
        _open_global_kind_bounce_cooldown()
        breaker_dt = _open_breaker(conn_id)
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "kind_bounce",
            "outcome": "ESCALATE",
            "failure_reason": f"kind_bounce_ssm: {bounce_detail} ({trigger_tag})"[:500],
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_cancel_restart_staleness,
            "verification_method": "kind_bounce_ssm_failed",
            "breaker_until_at": breaker_dt,
        })
        _publish_sns(
            f"[Airbyte KIND-BOUNCE ESCALATE] {conn_id} bounce failed ({trigger_reason})",
            _build_kind_bounce_escalate_email(
                conn_id, pre_staleness, post_cancel_restart_staleness, bounce_detail,
                trigger_reason=trigger_reason,
            ),
        )
        _post_clickup_comment(
            _build_clickup_kind_bounce_escalate_comment(
                conn_id, pre_staleness, post_cancel_restart_staleness, bounce_detail,
                trigger_reason=trigger_reason,
            )
        )
        return

    # bounce_status == KIND_BOUNCE_SSM_SUCCESS: control plane restarted + healthy.
    # The bounce reclassifies the stuck zero-byte job as succeeded but does NOT
    # auto-retry, and the S3 Iceberg connections are manual-trigger — so kick a
    # fresh sync explicitly before verifying. Open the global cooldown now: a
    # real bounce happened, so we must not re-bounce the shared control plane
    # for KIND_BOUNCE_COOLDOWN_SECONDS regardless of the sync outcome below.
    _open_global_kind_bounce_cooldown()
    LOGGER.info(json.dumps({
        "event": "kind_bounce_post_restart_cancel_restart",
        "connection_id": conn_id,
    }))
    try:
        pb_cancelled_job, pb_restart_job, pb_failure = _ssm_cancel_and_restart(
            conn_id, poll_timeout_seconds=KIND_BOUNCE_POST_RESTART_POLL_SECONDS
        )
    except Exception as exc:  # non-fatal: the fresh sync may still have been kicked
        pb_cancelled_job = pb_restart_job = None
        pb_failure = f"post_restart_exception: {exc}"
    if pb_failure:
        LOGGER.warning(json.dumps({
            "event": "kind_bounce_post_restart_cancel_restart_failed",
            "connection_id": conn_id,
            "error": pb_failure,
        }))
    else:
        # Surface the fresh sync's job ids in the audit trail.
        cancelled_job = pb_cancelled_job or cancelled_job
        restart_job = pb_restart_job or restart_job

    # Guard the in-line verify against the 900s Lambda hard timeout. A slow-but-
    # successful bounce (reconciled up to 240s) can leave < KIND_BOUNCE_VERIFY_WAIT
    # of budget. The global cooldown is already open (a real bounce ran) and the
    # fresh sync is already kicked, so defer verification to the next invocation's
    # freshness check rather than risk a hard kill that would drop the audit row.
    if not _has_budget_for(KIND_BOUNCE_VERIFY_WAIT_SECONDS + KIND_BOUNCE_VERIFY_BUDGET_MARGIN_SECONDS):
        LOGGER.warning(json.dumps({
            "event": "kind_bounce_verify_deferred_low_budget",
            "connection_id": conn_id,
        }))
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "kind_bounce",
            "outcome": "ESCALATE",
            "failure_reason": f"kind_bounce_verify_deferred_low_budget ({trigger_tag})",
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_cancel_restart_staleness,
            "verification_method": "deferred_to_next_cycle",
        })
        _publish_sns(
            f"[Airbyte KIND-BOUNCE PENDING] {conn_id} bounced; verify deferred to next cycle ({trigger_reason})",
            (
                f"Tier 2 kind-bounce for {conn_id} SUCCEEDED and a fresh sync was "
                f"kicked, but in-line verification was deferred to the next cron "
                f"invocation to stay under the Lambda time budget.\n\n"
                f"  Pre-restart staleness:  {pre_staleness} min\n"
                f"  Post-restart staleness: {post_cancel_restart_staleness} min\n\n"
                f"Global bounce cooldown is OPEN "
                f"({KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h); no per-connection "
                f"breaker was set. The next cycle's freshness check confirms recovery.\n"
            ),
        )
        _post_clickup_comment(
            f"🟠 KIND-BOUNCE PENDING: **{conn_id}** bounced + fresh sync kicked; "
            f"in-line verify deferred to next cycle (time budget). Global cooldown "
            f"open ({KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h), no breaker."
        )
        return

    LOGGER.info(json.dumps({
        "event": "kind_bounce_sleeping_for_verification",
        "connection_id": conn_id,
        "wait_seconds": KIND_BOUNCE_VERIFY_WAIT_SECONDS,
        "trigger_reason": trigger_reason,
    }))
    time.sleep(KIND_BOUNCE_VERIFY_WAIT_SECONDS)

    post_bounce_staleness, verification_method = _verify_recovery(
        snowflake_conn, conn_id, post_cancel_restart_staleness, bounce_command_time
    )

    if verification_method == "both_inconclusive_escalated":
        breaker_dt = _open_breaker(conn_id)
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "kind_bounce",
            "outcome": "ESCALATE",
            "failure_reason": f"kind_bounce_did_not_recover ({trigger_tag})",
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_bounce_staleness,
            "verification_method": verification_method,
            "breaker_until_at": breaker_dt,
        })
        _publish_sns(
            f"[Airbyte KIND-BOUNCE ESCALATE] {conn_id} did not recover after bounce ({trigger_reason})",
            _build_kind_bounce_escalate_email(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                "kind_bounce_did_not_recover", post_bounce_staleness,
                trigger_reason=trigger_reason,
            ),
        )
        _post_clickup_comment(
            _build_clickup_kind_bounce_escalate_comment(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                "kind_bounce_did_not_recover", post_bounce_staleness,
                trigger_reason=trigger_reason,
            )
        )
    else:
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "kind_bounce",
            "outcome": "AUTO_FIX",
            "failure_reason": trigger_tag,
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_bounce_staleness,
            "verification_method": verification_method,
        })
        _publish_sns(
            f"[Airbyte KIND-BOUNCE AUTO-FIX] {conn_id} recovered "
            f"({post_cancel_restart_staleness}m → {post_bounce_staleness}m, {trigger_reason})",
            _build_kind_bounce_autofix_email(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                post_bounce_staleness, trigger_reason=trigger_reason,
            ),
        )
        _post_clickup_comment(
            _build_clickup_kind_bounce_autofix_comment(
                conn_id, pre_staleness, post_cancel_restart_staleness,
                post_bounce_staleness, trigger_reason=trigger_reason,
            )
        )


# ----------------------------------------------------------------------------
# Step 3 helpers: DynamoDB breaker
# ----------------------------------------------------------------------------

def _check_breaker(conn_id: str) -> datetime | None:
    """Returns breaker_until datetime if open, else None."""
    try:
        resp = ddb_client.get_item(
            TableName=DDB_TABLE,
            Key={"connection_id": {"S": conn_id}},
            ConsistentRead=True,
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({"event": "breaker_read_failure", "connection_id": conn_id, "error": str(exc)}))
        return None

    item = resp.get("Item")
    if not item:
        return None
    breaker_until_epoch = int(item.get("breaker_until", {}).get("N", "0"))
    now_epoch = int(time.time())
    if breaker_until_epoch > now_epoch:
        return datetime.fromtimestamp(breaker_until_epoch, tz=timezone.utc)
    return None


def _open_breaker(conn_id: str) -> datetime:
    breaker_until_epoch = int(time.time()) + BREAKER_LOCK_SECONDS
    breaker_until_dt = datetime.fromtimestamp(breaker_until_epoch, tz=timezone.utc)
    try:
        ddb_client.put_item(
            TableName=DDB_TABLE,
            Item={
                "connection_id": {"S": conn_id},
                "breaker_until": {"N": str(breaker_until_epoch)},
                "last_attempt_at": {"N": str(int(time.time()))},
                "ttl": {"N": str(breaker_until_epoch + 60)},
            },
        )
    except Exception as exc:
        LOGGER.warning(json.dumps({"event": "breaker_write_failure", "connection_id": conn_id, "error": str(exc)}))
    return breaker_until_dt


# ----------------------------------------------------------------------------
# Step 4: persist + notify
# ----------------------------------------------------------------------------

def _write_audit_row(conn, row: dict) -> None:
    columns = [k for k in row if row[k] is not None]
    placeholders = ", ".join([f"%({c})s" for c in columns])
    column_list = ", ".join(columns)
    sql = f"insert into {SNOW_AUDIT_TABLE} ({column_list}) values ({placeholders})"
    payload = {c: row[c] for c in columns}
    cur = conn.cursor()
    cur.execute(sql, payload)


def _publish_sns(subject: str, body: str) -> None:
    try:
        sns_client.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject[:100], Message=body)
    except Exception as exc:
        LOGGER.warning(json.dumps({"event": "sns_publish_failure", "subject": subject[:80], "error": str(exc)}))


def _post_clickup_comment(text: str) -> None:
    try:
        token_secret = json.loads(secrets_client.get_secret_value(SecretId=SECRET_CLICKUP)["SecretString"])
        token = token_secret["token"]
        resp = requests.post(
            f"https://api.clickup.com/api/v2/task/{CLICKUP_TASK_ID}/comment",
            headers={"Authorization": token, "Content-Type": "application/json"},
            json={"comment_text": text},
            timeout=10,
        )
        if resp.status_code >= 400:
            LOGGER.warning(json.dumps({
                "event": "clickup_post_non_2xx",
                "status_code": resp.status_code,
                "body": resp.text[:300],
            }))
    except Exception as exc:
        LOGGER.warning(json.dumps({"event": "clickup_post_failure", "error": str(exc)}))


def _emergency_escalate(conn_id: str, error: str, request_id: str) -> None:
    """Last-resort SNS publish when the per-connection processing crashed
    before a structured outcome row could be written."""
    _publish_sns(
        f"[Airbyte ESCALATE] {conn_id} lambda_internal_error",
        f"Lambda invocation {request_id} crashed while processing {conn_id}.\n"
        f"Error: {error}\n\n"
        f"Audit row may be missing. Investigate: "
        f"aws logs tail /aws/lambda/airbyte-auto-remediate --since 30m\n"
        f"Phase 1 email layer is unaffected."
    )


# ----------------------------------------------------------------------------
# Email + ClickUp body builders
# ----------------------------------------------------------------------------

def _runbook_url() -> str:
    return ("https://github.com/trinitybi/dbt_ammodepot/blob/main/"
            "docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md")


def _build_observe_email(conn_id: str, pre_staleness: int, breach: dict) -> str:
    return (
        f"Connection {conn_id} crossed ALERT threshold "
        f"({pre_staleness} min stale, threshold {breach.get('ALERT_MINUTES')} min).\n\n"
        f"Lambda is in OBSERVE-ONLY mode — no action taken.\n"
        f"Would have: cancel current job, trigger fresh sync, verify after 5 min.\n\n"
        f"To enable live action:\n"
        f"  aws ssm put-parameter --name {OBSERVE_ONLY_PARAM} "
        f"--value false --overwrite --profile ammodepot\n\n"
        f"Runbook: {_runbook_url()}\n"
    )


def _build_autofix_email(conn_id: str, pre: int, post: int,
                         cancelled_job: str | None, restart_job: str | None) -> str:
    return (
        f"Auto-remediation succeeded for {conn_id}.\n\n"
        f"  Pre-restart staleness:  {pre} min\n"
        f"  Post-restart staleness: {post} min\n"
        f"  Cancelled job: {cancelled_job or '(none — no running job to cancel)'}\n"
        f"  Restart job:   {restart_job}\n\n"
        f"No action required. Phase 1 email layer is unaffected.\n"
        f"Audit log: SELECT * FROM ad_analytics.ops.airbyte_remediation_log "
        f"WHERE event_time >= dateadd('hour', -1, current_timestamp()) "
        f"ORDER BY event_time DESC;\n"
    )


def _build_escalate_email(conn_id: str, pre: int, failure: str,
                          cancelled_job: str | None, restart_job: str | None,
                          post: int | None = None) -> str:
    breaker_until = (datetime.now(timezone.utc) + timedelta(seconds=BREAKER_LOCK_SECONDS)).isoformat()
    return (
        f"Auto-remediation FAILED for {conn_id} — manual intervention required.\n\n"
        f"  Pre-restart staleness:  {pre} min\n"
        f"  Post-restart staleness: {post if post is not None else 'unknown'} min\n"
        f"  Cancelled job: {cancelled_job or '(none / unknown)'}\n"
        f"  Restart job:   {restart_job or '(none / unknown)'}\n"
        f"  Failure:       {failure}\n\n"
        f"Circuit breaker is OPEN until {breaker_until} "
        f"({BREAKER_LOCK_SECONDS // 60} min). Lambda will not retry until then.\n\n"
        f"Manual remediation: docs/AIRBYTE_INCIDENT_RUNBOOK.md (Phase 1 procedure).\n"
        f"Reset breaker early via: docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md\n"
    )


def _build_clickup_observe_comment(conn_id: str, pre_staleness: int) -> str:
    return (
        f"🟡 OBSERVE-ONLY: would have cancel-and-restarted **{conn_id}** "
        f"@ {pre_staleness} min stale. Lambda took no action."
    )


def _build_clickup_autofix_comment(conn_id: str, pre: int, post: int,
                                   cancelled_job: str | None, restart_job: str | None) -> str:
    return (
        f"✅ AUTO-FIX: **{conn_id}** recovered from {pre}m → {post}m staleness. "
        f"Cancelled job `{cancelled_job or 'n/a'}`, restart job `{restart_job}`. "
        f"No human action needed."
    )


def _build_clickup_escalate_comment(conn_id: str, pre: int, failure: str,
                                    cancelled_job: str | None, restart_job: str | None,
                                    post: int | None = None) -> str:
    return (
        f"🔴 ESCALATE: **{conn_id}** auto-remediation failed — manual action required.\n"
        f"- Pre-restart: {pre}m stale\n"
        f"- Post-restart: {post if post is not None else 'unknown'}m stale\n"
        f"- Cancelled job: `{cancelled_job or 'n/a'}`\n"
        f"- Restart job: `{restart_job or 'n/a'}`\n"
        f"- Failure: `{failure}`\n\n"
        f"Breaker open for {BREAKER_LOCK_SECONDS // 60} min. "
        f"See [auto-remediation runbook]({_runbook_url()})."
    )


# ----------------------------------------------------------------------------
# Email + ClickUp body builders: Tier 2 (kind-bounce)
# ----------------------------------------------------------------------------

def _trigger_reason_explanation(trigger_reason: str | None) -> str:
    if trigger_reason == "deep_stuck":
        return (
            f"deep_stuck (post-restart staleness > "
            f"{KIND_BOUNCE_TRIGGER_POST_MIN} min)"
        )
    if trigger_reason == "repeat_pattern":
        return (
            f"repeat_pattern (≥{KIND_BOUNCE_REPEAT_COUNT} cancel+restart "
            f"attempts in last {KIND_BOUNCE_REPEAT_WINDOW_MIN} min)"
        )
    return "unknown"


def _build_kind_bounce_observe_email(conn_id: str, pre_staleness: int,
                                     post_staleness: int,
                                     trigger_reason: str | None = None) -> str:
    return (
        f"Connection {conn_id} did not recover after cancel+restart "
        f"({pre_staleness}m → {post_staleness}m).\n\n"
        f"Trigger: {_trigger_reason_explanation(trigger_reason)}\n"
        f"Lambda Tier 2 (kind-bounce) is in OBSERVE-ONLY mode — no action taken.\n"
        f"Would have: docker restart airbyte-abctl-control-plane, verify in 3 min.\n\n"
        f"To enable live Tier 2 action:\n"
        f"  aws ssm put-parameter --name {KIND_BOUNCE_OBSERVE_ONLY_PARAM} "
        f"--value false --overwrite --profile ammodepot\n\n"
        f"Runbook: {_runbook_url()}\n"
    )


def _build_kind_bounce_autofix_email(conn_id: str, pre: int, post_restart: int,
                                     post_bounce: int,
                                     trigger_reason: str | None = None) -> str:
    return (
        f"Tier 2 kind-bounce SUCCEEDED for {conn_id}.\n\n"
        f"  Trigger:                  {_trigger_reason_explanation(trigger_reason)}\n"
        f"  Pre-restart staleness:    {pre} min\n"
        f"  Post-restart staleness:   {post_restart} min  (cancel+restart insufficient)\n"
        f"  Post-bounce staleness:    {post_bounce} min  (control-plane restart fixed it)\n\n"
        f"docker restart airbyte-abctl-control-plane completed successfully.\n"
        f"Global kind-bounce cooldown opened for "
        f"{KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h.\n\n"
        f"Audit log: SELECT * FROM ad_analytics.ops.airbyte_remediation_log "
        f"WHERE event_time >= dateadd('hour', -1, current_timestamp()) "
        f"AND action_taken = 'kind_bounce' ORDER BY event_time DESC;\n"
    )


def _build_kind_bounce_escalate_email(conn_id: str, pre: int, post_restart: int,
                                      failure: str,
                                      post_bounce: int | None = None,
                                      trigger_reason: str | None = None) -> str:
    return (
        f"Tier 2 kind-bounce FAILED for {conn_id} — manual intervention required.\n\n"
        f"  Trigger:                  {_trigger_reason_explanation(trigger_reason)}\n"
        f"  Pre-restart staleness:    {pre} min\n"
        f"  Post-restart staleness:   {post_restart} min\n"
        f"  Post-bounce staleness:    "
        f"{post_bounce if post_bounce is not None else 'unknown'} min\n"
        f"  Failure:                  {failure}\n\n"
        f"Global kind-bounce cooldown opened for "
        f"{KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h — "
        f"Lambda will not bounce again until then.\n"
        f"Per-connection breaker opened for {BREAKER_LOCK_SECONDS // 60} min.\n\n"
        f"Manual recovery: see 'Tier 2: Kind-Bounce' section of "
        f"docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md\n"
        f"Phase 1 email layer is unaffected.\n"
    )


def _build_clickup_kind_bounce_observe_comment(conn_id: str, pre: int, post: int,
                                               trigger_reason: str | None = None) -> str:
    return (
        f"🟡 KIND-BOUNCE OBSERVE: **{conn_id}** would have control-plane-bounced "
        f"(pre={pre}m → post-restart={post}m, "
        f"trigger=`{trigger_reason or 'unknown'}`). "
        f"Lambda took no Tier 2 action."
    )


def _build_clickup_kind_bounce_autofix_comment(conn_id: str, pre: int,
                                               post_restart: int,
                                               post_bounce: int,
                                               trigger_reason: str | None = None) -> str:
    return (
        f"🔁 KIND-BOUNCE AUTO-FIX: **{conn_id}** recovered after control-plane bounce.\n"
        f"- Trigger: `{trigger_reason or 'unknown'}`\n"
        f"- Pre-restart: {pre}m → Post-restart: {post_restart}m → "
        f"Post-bounce: {post_bounce}m\n"
        f"- `docker restart airbyte-abctl-control-plane` SUCCEEDED\n"
        f"- Global bounce cooldown engaged for "
        f"{KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h"
    )


def _build_clickup_kind_bounce_escalate_comment(conn_id: str, pre: int,
                                                post_restart: int, failure: str,
                                                post_bounce: int | None = None,
                                                trigger_reason: str | None = None) -> str:
    return (
        f"🔴 KIND-BOUNCE ESCALATE: **{conn_id}** Tier 2 failed — manual action required.\n"
        f"- Trigger: `{trigger_reason or 'unknown'}`\n"
        f"- Pre-restart: {pre}m → Post-restart: {post_restart}m → "
        f"Post-bounce: {post_bounce if post_bounce is not None else 'unknown'}m\n"
        f"- Failure: `{failure}`\n"
        f"- Both cooldowns engaged "
        f"(global {KIND_BOUNCE_COOLDOWN_SECONDS // 3600}h + "
        f"per-connection {BREAKER_LOCK_SECONDS // 60}m)\n"
        f"- See [runbook]({_runbook_url()}) Tier 2 section"
    )


def _build_kind_bounce_unknown_email(conn_id: str, pre: int, post_restart: int,
                                     detail: str,
                                     trigger_reason: str | None = None) -> str:
    return (
        f"Tier 2 kind-bounce status UNCONFIRMED for {conn_id}.\n\n"
        f"  Trigger:                  {_trigger_reason_explanation(trigger_reason)}\n"
        f"  Pre-restart staleness:    {pre} min\n"
        f"  Post-restart staleness:   {post_restart} min\n"
        f"  Detail:                   {detail}\n\n"
        f"The bounce command's final status could not be confirmed within the "
        f"reconcile window, so NO global cooldown and NO per-connection breaker "
        f"were opened. The next cron invocation will re-detect and re-attempt if "
        f"the connection is still stale.\n\n"
        f"Manual recovery: see 'Tier 2: Kind-Bounce' section of "
        f"docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md\n"
        f"Phase 1 email layer is unaffected.\n"
    )


def _build_clickup_kind_bounce_unknown_comment(conn_id: str, pre: int,
                                               post_restart: int, detail: str,
                                               trigger_reason: str | None = None) -> str:
    return (
        f"🟠 KIND-BOUNCE UNKNOWN: **{conn_id}** bounce status unconfirmed.\n"
        f"- Trigger: `{trigger_reason or 'unknown'}`\n"
        f"- Pre-restart: {pre}m → Post-restart: {post_restart}m\n"
        f"- Detail: `{detail}`\n"
        f"- NO cooldown or breaker opened — next cycle re-detects and re-attempts.\n"
        f"- See [runbook]({_runbook_url()}) Tier 2 section"
    )
