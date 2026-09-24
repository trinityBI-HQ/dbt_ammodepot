# lambda/airbyte_auto_remediate/ — auto-remediation of stuck Airbyte syncs

Runs on EventBridge `cron(5,20,35,50)`, reads freshness from Snowflake, and acts on the Airbyte host
through SSM. What it does, the progress gate, deploy and operation: `README.md`. What each email
means, the observe-only switches, resetting the breaker: `../../docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md`.
Why it is built this way, and what was rejected: `../../docs/decisions/0008-auto-remediation-architecture.md`.

**Each tier has its own observe-only switch** in SSM: `/airbyte-auto-remediate/observe-only`
(Tier 1, cancel + restart) and `/airbyte-auto-remediate/kind-bounce-observe-only` (Tier 2,
kind-bounce). Read both before assuming either tier acts.

## Invariants — each one written by an incident

- **Infrastructure action only for a job that is live and not moving.** A `failed` or `cancelled`
  last job pages a human instead (`SKIP_JOB_FAILED`, PR #42): a permanent fault walked the ladder to a
  kind-bounce and caused 13 hours of downtime (`../../docs/incidents/2026-09-19-remediation-13h-outage.md`).
  A `succeeded` job within `MAX_SUCCEEDED_JOB_AGE_SEC` means the connector works, so staleness is
  seasonality or monitoring lag (`SKIP_JOB_SUCCEEDED`, PR #44): it bounced a healthy platform
  (`../../docs/incidents/2026-09-21-remediation-bounced-healthy-platform.md`).
- **Absent evidence never spares a cancel** — missing or unparseable evidence falls through to `ACT`,
  and only positive evidence of movement skips. A job younger than `MIN_ZERO_PROGRESS_JOB_AGE_SEC`
  (1500 s) is `SKIP_JOB_TOO_YOUNG`: Airbyte publishes counters on commit, so a healthy sync reads 0
  bytes for its whole run (p99 ≈ 20 min).
- **The kind-bounce is `docker restart -t 120`**, never without `-t`.
- **A slow bounce is not a failed one.** The SSM command is reconciled to its real terminal status
  before classifying, and only a confirmed failure or a real success opens the global 6 h cooldown:
  a 120 s poll once labelled 77–166 s bounces failed, and the cooldown blocked all remediation
  (PR #23). The code keeps `KIND_BOUNCE_SSM_RECONCILE_SECONDS` above the poll timeout.
- **Restart through the internal API** (`/api/v1/connections/sync`). The public API 500s on anything
  that resolves a connection while per-connector memory caps are set — the Lambda was a pure kill
  switch until PR #34. Do not "simplify" it back.
- **Progress samples live under `progress#<connection_id>`** in DynamoDB — the breaker's bare key
  would be clobbered, since `put_item` replaces the whole item.
- **A logging table must never reject a row.** `CHK_OUTCOME` on `AIRBYTE_REMEDIATION_LOG` *is*
  enforced; it aborted processing and the event vanished, so it was dropped.
  `chk_connection` will throw the same way on a third connector.

## Traps

- **`deploy.sh --infra-only` does not update the Lambda's config**, and CI only swaps the image.
  Timeout, memory or environment defaults changed in `deploy.sh` reach the running Lambda only
  through `./deploy.sh full`.
- **A plain local `docker build` on Docker 25+ writes OCI 1.1 manifests with attestations, which
  Lambda rejects.** `deploy.sh` builds with `buildx --platform linux/amd64 --provenance=false
  --sbom=false` — build through it.
- **`ssm_poll_deadline_exceeded` means the Lambda stopped polling** — not that the command failed.
  Ask SSM (`get-command-invocation`) for the real status.
- **`AIRBYTE_REMEDIATION_LOG.event_time` is NTZ in America/Los_Angeles**, not UTC.
- **The circuit breaker sets a floor on repeats**: after an escalation, the same connection cannot be
  acted on again sooner than breaker + cadence + jitter (2 h + 15 min + jitter).
- **Verify a fix over ≥ 3× the failure interval.** Container-scoped counters (`memory.events`,
  `restartCount`) reset with the process: a pod 8 minutes old reads clean against a 2.7-hour failure
  cycle, and one such fix was ~6× worse the next day.
- **Connection-level freshness is MAX-of-MAX** — the busiest stream's last extract. Idle config
  tables are legitimately stale, so any MIN-based signal alarms on them.
