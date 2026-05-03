"""airbyte-auto-remediate — Lambda handler.

Single-invocation orchestration:
  1. Read flags + state (SSM Parameter, Secrets Manager, DynamoDB)
  2. Detect ALERT-tier breaches (Snowflake V_AIRBYTE_FRESHNESS)
  3. For each breached connection (parallel via ThreadPoolExecutor):
     a. Check breaker (skip if open)
     b. Check observe-only (log decision; skip action)
     c. Cancel + restart via SSM SendCommand
     d. Sleep 300 s
     e. Verify: Snowflake re-query first; S3 LIST per-table fallback
     f. Determine outcome
  4. Persist + notify (Snowflake audit row + ClickUp comment + SNS publish)

Time budget per connection (worst case): detect 2s + (cancel+restart 30s) +
sleep 300s + verify 10s + notify 5s = 347s. Two connections in parallel:
~350s. Lambda timeout 600s, headroom ~250s.
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

SSM_PAYLOAD_TEMPLATE_PATH = Path(__file__).parent / "ssm-payloads" / "cancel_and_restart.json.tmpl"


# ----------------------------------------------------------------------------
# Module-scoped boto3 clients (re-used across warm invocations)
# ----------------------------------------------------------------------------

ssm_client = boto3.client("ssm")
sns_client = boto3.client("sns")
secrets_client = boto3.client("secretsmanager")
ddb_client = boto3.client("dynamodb")
s3_client = boto3.client("s3")


# ----------------------------------------------------------------------------
# Lambda entry point
# ----------------------------------------------------------------------------

def handler(event, context):
    """EventBridge invokes this every 15 min on cron(5,20,35,50)."""
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
        breaker_dt = _open_breaker(conn_id)
        _write_audit_row(snowflake_conn, {
            **base_audit,
            "action_taken": "cancel_and_restart",
            "outcome": "ESCALATE",
            "failure_reason": "restart_did_not_recover",
            "cancelled_job_id": cancelled_job,
            "restart_job_id": restart_job,
            "post_staleness_min": post_staleness,
            "verification_method": verification_method,
            "breaker_until_at": breaker_dt,
        })
        _publish_sns(
            f"[Airbyte ESCALATE] {conn_id} did not recover ({post_staleness}m post-restart)",
            _build_escalate_email(conn_id, pre_staleness, "restart_did_not_recover",
                                  cancelled_job, restart_job, post_staleness),
        )
        _post_clickup_comment(_build_clickup_escalate_comment(
            conn_id, pre_staleness, "restart_did_not_recover",
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

def _ssm_cancel_and_restart(conn_id: str) -> tuple[str | None, str | None, str | None]:
    """Returns (cancelled_job_id, restart_job_id, failure_reason).

    failure_reason is None on success.
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

    deadline = time.time() + SSM_POLL_TIMEOUT_SECONDS
    inv = None
    while time.time() < deadline:
        time.sleep(SSM_POLL_INTERVAL_SECONDS)
        try:
            inv = ssm_client.get_command_invocation(CommandId=command_id, InstanceId=AIRBYTE_INSTANCE_ID)
        except ssm_client.exceptions.InvocationDoesNotExist:
            continue
        if inv["Status"] in ("Success", "Failed", "TimedOut", "Cancelled"):
            break

    if inv is None or inv.get("Status") not in ("Success", "Failed", "TimedOut", "Cancelled"):
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
