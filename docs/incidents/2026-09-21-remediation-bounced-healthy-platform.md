---
paths: ["lambda/airbyte_auto_remediate/**", "streamlit_cost_monitor/setup/08_airbyte_remediation_log.sql"]
---
# 2026-09-21 — Auto-remediation bounced a healthy platform

Two days after the 13-hour outage, the Lambda bounced the control plane again — on a platform with
nothing wrong with it: 11 pod restarts, no justification. The `-t 120` restart from PR #42 held, so
nothing was corrupted.

## There was no incident

Magento committed rows on every sync in the window — 1292, 1426, 940, 779, 743, 262, 425 — never a
failure and never a zero; Fishbowl ~3,500 rows a run; dbt built successfully every 15 minutes.
**Check the connector, not the freshness view**: the view was the only thing reporting a problem.

## The gate had the opposite hole from the one PR #42 closed

```python
if status in _FAILED_JOB_STATUSES:     # failed/cancelled -> SKIP  (PR #42)
    return "SKIP_JOB_FAILED", ...
if status not in _LIVE_JOB_STATUSES:   # "succeeded" landed HERE
    return "ACT", f"job_not_live:{status}"
```

A `succeeded` last job fell through to `ACT`, logged as `job_not_live:succeeded`. That success had
finished 51 seconds before the Lambda cancelled, restarted, and then bounced the cluster.

**Fix (PR #44): `SKIP_JOB_SUCCEEDED`.** A success within `MAX_SUCCEEDED_JOB_AGE_SEC` (3600) means the
connector works, so staleness is source seasonality or monitoring lag, and a restart repairs neither.
Past that age a wedged scheduler is plausible, and the gate still acts.

## Why the view lied

Snowflake sees new Iceberg data only after `ecs/refresh_iceberg.py`, which the ECS task runs before
each `dbt build` — and the Lambda fires on the same `5,20,35,50` schedule, so it reads the landing
tables before that cycle's refresh lands. Add Fishbowl's quiet overnight hours, and a
destination-freshness monitor cannot tell "no changes", "not refreshed yet" and "frozen" apart.

## A CHECK constraint documented as inert

The context file said `chk_outcome` on `AIRBYTE_REMEDIATION_LOG` was documentation only. It is
enforced:

```
001185 (23514): Operation on table AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG failed
because CHECK constraint CHK_OUTCOME ... was violated
```

Writing the new outcome `SKIPPED_PROGRESSING` threw, the exception aborted processing
(`connection_processing_failed`), and the event vanished from the audit trail. The trap is silent:
`create table if not exists` never updates an existing CHECK, so the live table kept an older
vocabulary than the bootstrap file. The constraint was dropped in production and removed from
`08_airbyte_remediation_log.sql`. That file still declares `chk_connection` and `chk_tier`; either
throws the same way on a value outside its list — a third connector, a tier other than `ALERT`.

## Posture afterwards

Tier 2 (kind-bounce) `observe-only=true` pending a soak; Tier 1 (cancel + restart) armed.
