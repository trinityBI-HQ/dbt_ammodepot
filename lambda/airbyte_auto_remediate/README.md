# airbyte-auto-remediate

> AWS Lambda — autonomous cancel + restart of stuck Airbyte → S3 Iceberg syncs.
> Phase 2 of [Airbyte Observability](../../docs/AIRBYTE_INCIDENT_RUNBOOK.md).

## What it does

Every 15 min on `cron(5,20,35,50)` UTC, this Lambda:

1. Reads `AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS` (Phase 1's view).
2. For every connection in `ALERT` tier (≥30 min stale by default):
   - Checks the per-connection DynamoDB circuit breaker. Skips if open.
   - **Progress gate:** skips entirely if the running job is *committing*
     (see below). Staleness alone cannot tell "frozen" from "slow".
   - **Tier 1 (cancel+restart):** if `OBSERVE_ONLY=true`, logs the would-be
     action. Otherwise cancels the running Airbyte job + triggers a fresh
     sync via SSM, sleeps 5 min, verifies recovery.
   - **Tier 2 (kind-bounce, Phase 2.1):** if Tier 1 left `post_staleness_min > 60`,
     and global cooldown is clear, and the *other* connection is idle, and
     `kind-bounce-observe-only=false`, then issues
     `docker restart airbyte-abctl-control-plane` via SSM and re-verifies
     after 3 min. Opens a global 6h cooldown after any bounce.
   - Writes one row to `AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG`.
   - Publishes one of `[Airbyte AUTO-FIX]`, `[Airbyte ESCALATE]`,
     `[Airbyte KIND-BOUNCE *]` to SNS → email; posts matching ClickUp comment.

Phase 1's email layer (`[Airbyte WARN]` / `[Airbyte ALERT]`) is unchanged
and continues to fire independently.

## Progress gate (added 2026-07-22)

**Why:** on 2026-07-22 Magento was draining a backlog — every sync *was* moving
data, just slower than the 30-min threshold — and this Lambda cancelled it four
times. Each cancel discarded real work (job 28578 lost **1h21m**) and the restart
re-read the binlog from the last committed offset, so the connection could never
catch up. **The remediation became the outage.**

Staleness alone conflates two opposite states:

| State | Signature | Correct action |
|---|---|---|
| **Frozen** | live job, `bytesSynced=0`, offset stuck | cancel + restart |
| **Slow but committing** | counters advancing between samples | **leave it alone** |

The gate runs after the breaker and *before* the observe-only branch, so an
observe-only soak reports the real decision. Decisions:

| Decision | When |
|---|---|
| `ACT` | no live job · `bytesSynced=0` on a live job (classic freeze — acts immediately, no baseline wait) · counters flat between two samples · **any** missing/unparseable evidence |
| `SKIP_PROGRESSING` | counters advanced vs the prior sample for the same job |
| `SKIP_NEED_BASELINE` | data is moving but no comparable prior sample (first sighting, or a new job — counters reset per job); records one and re-evaluates next run (~15 min) |

**Bias: only skip on positive evidence of movement.** Any doubt falls through to
`ACT`, preserving pre-gate behaviour. Skips write an audit row with outcome
`SKIPPED_PROGRESSING` and log `skipped_progress_gate`.

Prior observations live in the same DynamoDB table under a **separate key**
(`progress#<connection_id>`) — the breaker writes with `put_item`, which replaces
the whole item, so sharing a key would silently clobber `breaker_until`.

Rollback without redeploy: `PROGRESS_GATE_ENABLED=false`
(`aws lambda update-function-configuration`) restores the old always-cancel path.

Tests: `python3 test_progress_gate.py` (9 cases, no AWS/Snowflake needed).

## Architecture (one-liner)

```
EventBridge → Lambda → SSM → Airbyte EC2 → (5-min sleep) → Snowflake/S3 verify → SNS + ClickUp + audit row
```

Detailed design: [`.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md).

## Files

| File | Role |
|------|------|
| `main.py` | Lambda handler (single function: `handler`) |
| `pyproject.toml` | Runtime deps (boto3, snowflake-connector, requests) |
| `Dockerfile` | Container image — `public.ecr.aws/lambda/python:3.11` base |
| `ssm-payloads/cancel_and_restart.json.tmpl` | SSM `SendCommand` payload — `__CONNECTION_ID__` substituted at runtime |
| `ssm-payloads/kind_bounce.json.tmpl` | SSM `SendCommand` payload for Tier 2 — `docker restart airbyte-abctl-control-plane` + readiness probe |
| `iam-policies/lambda-trust.json` | Trust policy for the Lambda role |
| `iam-policies/lambda-execution-role.json` | Inline execution policy (least-privilege) |
| `iam-policies/eventbridge-trust.json` | Trust policy for EventBridge → Lambda |
| `iam-policies/eventbridge-rule.json` | EventBridge rule definition |
| `deploy.sh` | One-shot manual deploy (idempotent; mirrors `ecs/deploy.sh`) |

## Deploy

### First deploy (full bootstrap)

```bash
# From repo root, AFTER running streamlit_cost_monitor/setup/08_airbyte_remediation_log.sql:
cd lambda/airbyte_auto_remediate
./deploy.sh
```

This provisions ECR, SNS, DynamoDB, SSM Parameter (default `OBSERVE_ONLY=true`),
IAM role, Lambda function, EventBridge rule, and CloudWatch alarms.

The script will **warn** if the ClickUp secret is missing — create it before
the first scheduled invocation:

```bash
aws secretsmanager create-secret \
    --profile ammodepot --region us-east-1 \
    --name ammodepot/airbyte-auto-remediate/clickup \
    --description 'ClickUp personal API token for posting remediation comments' \
    --secret-string '{"token":"pk_YOUR_CLICKUP_TOKEN"}'
```

Confirm the SNS subscription email when it arrives.

### Subsequent deploys

GitHub Actions auto-builds + deploys on push to `main` (path-filtered to
`lambda/airbyte_auto_remediate/**`).
See `.github/workflows/deploy-lambda-airbyte-auto-remediate.yml`.

Manual fallback: `./deploy.sh --image-only` (skip infra provisioning).

## Operate

### Toggle observe-only

Two independent flags — Tier 1 (cancel+restart) and Tier 2 (kind-bounce) can be
gated separately:

```bash
# Tier 1: pause cancel+restart (force observe-only):
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value true --overwrite --profile ammodepot

# Tier 1: enable live cancel+restart:
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value false --overwrite --profile ammodepot

# Tier 2: pause kind-bounce (cancel+restart still runs live):
aws ssm put-parameter --name /airbyte-auto-remediate/kind-bounce-observe-only \
    --value true --overwrite --profile ammodepot

# Tier 2: enable live kind-bounce (after ≥3-day soak):
aws ssm put-parameter --name /airbyte-auto-remediate/kind-bounce-observe-only \
    --value false --overwrite --profile ammodepot
```

### Reset breaker for a connection

```bash
# Per-connection breaker (2h after a failed cancel+restart):
aws dynamodb delete-item \
    --profile ammodepot \
    --table-name airbyte-auto-remediate-state \
    --key '{"connection_id":{"S":"magento_s3"}}'

# Global kind-bounce cooldown (6h after any kind-bounce attempt):
aws dynamodb delete-item \
    --profile ammodepot \
    --table-name airbyte-auto-remediate-state \
    --key '{"connection_id":{"S":"_GLOBAL_KIND_BOUNCE"}}'
```

### Disable Lambda (emergency)

```bash
aws lambda put-function-concurrency \
    --profile ammodepot \
    --function-name airbyte-auto-remediate \
    --reserved-concurrent-executions 0

# Re-enable:
aws lambda delete-function-concurrency \
    --profile ammodepot \
    --function-name airbyte-auto-remediate
```

### Tail logs

```bash
aws logs tail /aws/lambda/airbyte-auto-remediate --since 30m --profile ammodepot
```

### Inspect audit log

```sql
USE ROLE TRANSFORMER_ROLE;
SELECT
    event_time,
    connection_id,
    outcome,
    pre_staleness_min,
    post_staleness_min,
    failure_reason,
    verification_method
FROM AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG
WHERE event_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY event_time DESC;
```

## Cost

≤$2/mo recurring at the default 4×/hr cadence. CloudWatch billing alarm
fires at $5/mo as a hard cap. Free-tier coverage: Lambda invocations,
DynamoDB on-demand R/W (~10 ops/day), SNS publishes (<10/mo), SSM
Parameter retrievals (~3K/mo).

Snowflake compute reuses the existing `ETL_WH` (warm at the cron's
`:05/:20/:35/:50` minutes) and tags every Lambda query with
`QUERY_TAG = 'lambda:airbyte_auto_remediate'` for cost attribution.

## Troubleshooting

| Symptom | Probable cause | Fix |
|---------|----------------|-----|
| `[Airbyte ALERT]` from Phase 1 but no Lambda follow-up within 20 min | EventBridge rule disabled or Lambda concurrency capped | `aws events describe-rule --name airbyte-auto-remediate-schedule` + check `aws lambda get-function-concurrency` |
| `[Airbyte ESCALATE]` keeps recurring on same connection | Real upstream issue (Airbyte EC2 / Fishbowl source / Magento source) | Follow `docs/AIRBYTE_INCIDENT_RUNBOOK.md` (Phase 1 manual procedure) |
| ClickUp comments not appearing | Secret missing or token expired | Re-create `ammodepot/airbyte-auto-remediate/clickup` with fresh token |
| Lambda timeout (`Task timed out after 600.00 seconds`) | SSM hung mid-payload | Check Airbyte EC2 — `i-075043415ebad732f` may need a restart |

## See also

- Operator runbook: [`docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md`](../../docs/AIRBYTE_AUTO_REMEDIATION_RUNBOOK.md)
- Phase 1 (manual) runbook: [`docs/AIRBYTE_INCIDENT_RUNBOOK.md`](../../docs/AIRBYTE_INCIDENT_RUNBOOK.md)
- DEFINE (Phase 2): [`.claude/sdd/features/DEFINE_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DEFINE_AIRBYTE_AUTO_REMEDIATION.md)
- DESIGN (Phase 2): [`.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md`](../../.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md)
- DEFINE (Phase 2.1 kind-bounce): [`.claude/sdd/features/DEFINE_AIRBYTE_KIND_BOUNCE_TIER.md`](../../.claude/sdd/features/DEFINE_AIRBYTE_KIND_BOUNCE_TIER.md)
- DESIGN (Phase 2.1 kind-bounce): [`.claude/sdd/features/DESIGN_AIRBYTE_KIND_BOUNCE_TIER.md`](../../.claude/sdd/features/DESIGN_AIRBYTE_KIND_BOUNCE_TIER.md)
- ClickUp task: [86ah8bpmj](https://app.clickup.com/t/86ah8bpmj)
