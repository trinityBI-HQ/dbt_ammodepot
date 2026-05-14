# Airbyte Auto-Remediation — Operator Runbook

> Phase 2 follow-up to [Airbyte Observability](AIRBYTE_INCIDENT_RUNBOOK.md).
> AWS Lambda `airbyte-auto-remediate` autonomously cancels + restarts stuck
> Airbyte → S3 Iceberg syncs every 15 min on `cron(5,20,35,50)` UTC.

## TL;DR — what each email means

| Subject prefix | What happened | Action required? |
|----------------|---------------|------------------|
| `[Airbyte WARN]`  / `[Airbyte ALERT]` | **Phase 1** detection. Sync is stuck. Lambda will react on its next tick (≤16 min). | None yet — let Lambda try. |
| `[Airbyte AUTO-FIX]` | Lambda recovered the sync automatically. | None. Audit row written. |
| `[Airbyte ESCALATE]` | Lambda gave up. Breaker open for 2h. | **Yes** — manual remediation. See "If you got an ESCALATE" below. |
| `[Airbyte OBSERVE]` | Lambda is in observe-only mode. It would have acted but didn't. | Validate the decision against Phase 1 incident. |

## When does Lambda act?

- Connection in `ALERT` tier on `V_AIRBYTE_FRESHNESS` (default ≥60 min stale)
- Circuit breaker not open for that connection
- `OBSERVE_ONLY` SSM Parameter is `false`

The Lambda runs on the same cron as Phase 1's alerts (5/20/35/50 past the
hour, UTC), so it's typically <15 min between Phase 1's `[Airbyte ALERT]`
email and Lambda's outcome email.

## If you got an `[Airbyte ESCALATE]`

1. **Don't wait for Lambda to retry.** The breaker is open for 2 hours; Lambda
   intentionally backs off so you can investigate uninterrupted.

2. **Check the audit log for context:**

   ```sql
   USE ROLE TRANSFORMER_ROLE;
   SELECT * FROM AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG
   WHERE event_time >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
   ORDER BY event_time DESC
   LIMIT 5;
   ```

   The `failure_reason` column tells you why Lambda couldn't recover:

   | `failure_reason` | Likely root cause | Where to look |
   |------------------|-------------------|---------------|
   | `ssm_send_command_exception:*` | AWS SSM API rejected the command | CloudWatch Logs `/aws/lambda/airbyte-auto-remediate` |
   | `ssm_command_status=Failed; stderr=…` | Airbyte API rejected cancel/restart | The `stderr` snippet has the curl exit code |
   | `ssm_poll_deadline_exceeded` | Airbyte EC2 hung mid-payload | `i-075043415ebad732f` may need a restart |
   | `restart_did_not_recover` | Lambda's restart succeeded but new job is also stuck | Real upstream issue (Fishbowl/Magento source side) |
   | `restart_marker_missing:*` | Airbyte API responded but didn't return a job ID | Airbyte API may be in degraded state |

3. **Follow the Phase 1 (manual) runbook**: [`AIRBYTE_INCIDENT_RUNBOOK.md`](AIRBYTE_INCIDENT_RUNBOOK.md).

4. **After manual recovery, optionally reset the breaker** so Lambda can start
   protecting again sooner than 2h:

   ```bash
   aws dynamodb delete-item \
       --profile ammodepot \
       --table-name airbyte-auto-remediate-state \
       --key '{"connection_id":{"S":"magento_s3"}}'   # or fishbowl_s3
   ```

   Otherwise the breaker auto-resets via DynamoDB TTL after 2h.

## Common operator commands

### Toggle observe-only

```bash
# Pause Lambda action (force observe-only):
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value true --overwrite --profile ammodepot

# Re-enable live action:
aws ssm put-parameter --name /airbyte-auto-remediate/observe-only \
    --value false --overwrite --profile ammodepot
```

### Inspect last 7 days of audit log

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

### Check breaker state

```bash
aws dynamodb scan \
    --profile ammodepot \
    --table-name airbyte-auto-remediate-state \
    --query 'Items[*].[connection_id.S, breaker_until.N]' \
    --output table
```

### Tail Lambda logs

```bash
aws logs tail /aws/lambda/airbyte-auto-remediate \
    --profile ammodepot --since 30m --follow
```

### Disable Lambda entirely (emergency)

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

When Lambda is disabled, **Phase 1 emails still fire** and you can manually
remediate following the Phase 1 runbook. The two layers are independent by
design — disabling one doesn't disable the other.

### Force a Lambda invocation (for testing)

```bash
aws lambda invoke \
    --profile ammodepot \
    --function-name airbyte-auto-remediate \
    --invocation-type RequestResponse \
    --payload '{}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-out.json && cat /tmp/lambda-out.json
```

If `OBSERVE_ONLY=true`, Lambda is safe to invoke at any time. If `false` and
a connection is currently in ALERT, this WILL trigger a real cancel + restart.

## When to suspect Lambda is broken

- Phase 1 `[Airbyte ALERT]` email arrived but **no `[Airbyte AUTO-FIX]` or
  `[Airbyte ESCALATE]` follow-up within 20 min**.
- CloudWatch alarm `airbyte-auto-remediate-errors` fires (Errors ≥ 1 in 5 min).
- CloudWatch alarm `airbyte-auto-remediate-stale-invocations` fires (no
  invocations in 30 min — EventBridge rule may be disabled).
- ClickUp task 86ah8bpmj has no comments matching the latest incident.

In any of those cases, fall back to the Phase 1 manual runbook for the
current incident, then debug Lambda separately:

```bash
# Is the rule enabled?
aws events describe-rule --profile ammodepot \
    --name airbyte-auto-remediate-schedule \
    --query 'State'

# Is concurrency capped at 0?
aws lambda get-function-concurrency --profile ammodepot \
    --function-name airbyte-auto-remediate

# Recent errors?
aws logs filter-log-events --profile ammodepot \
    --log-group-name /aws/lambda/airbyte-auto-remediate \
    --filter-pattern '?ERROR ?Exception ?ESCALATE' \
    --start-time "$(date -d '2 hours ago' +%s)000" \
    --max-items 20
```

## When the Snowflake bootstrap needs to be re-run

If `AD_ANALYTICS.OPS.AIRBYTE_REMEDIATION_LOG` ever needs a schema change:

1. **Cordon Lambda**: `OBSERVE_ONLY=true` so no INSERTs land while you migrate.
2. Update `streamlit_cost_monitor/setup/08_airbyte_remediation_log.sql`.
3. Apply via Snowsight as ACCOUNTADMIN (the file is idempotent — `CREATE TABLE
   IF NOT EXISTS`, `GRANT`, etc.). For destructive changes, do an explicit
   `ALTER TABLE` outside the bootstrap so the bootstrap stays additive.
4. Update `lambda/airbyte_auto_remediate/main.py` `_write_audit_row` if column
   list changed.
5. Push to main → CI deploys the new Lambda image.
6. Flip `OBSERVE_ONLY=false`.

## Tier 2: Kind-Bounce (Phase 2.1 enhancement — control-plane restart)

When the Tier 1 cancel+restart leaves a connection at `post_staleness_min > 60`,
the Lambda escalates to Tier 2: `docker restart airbyte-abctl-control-plane`
via SSM. This recovers the kind/kube-scheduler stuck-state where the Airbyte
API accepts cancel+restart but the scheduler never schedules the new job's pod
(the failure signature behind the 0/13 magento_s3 restart success rate that
motivated this tier).

### Email subjects you may now see

| Subject | Meaning |
|---|---|
| `[Airbyte KIND-BOUNCE OBSERVE] <conn> would bounce @ <N>m` | Tier 2 is in observe-only mode; Lambda logged the decision but did NOT bounce. Audit row: `action_taken='would_kind_bounce'`. Tier 1 cancel+restart already ran. |
| `[Airbyte KIND-BOUNCE AUTO-FIX] <conn> recovered (<N>m → <M>m)` | `docker restart` succeeded; connection recovered after the bounce. Audit row: `action_taken='kind_bounce', outcome='AUTO_FIX'`. No human action needed. |
| `[Airbyte KIND-BOUNCE ESCALATE] <conn> ...` | Bounce was attempted but didn't recover (or SSM failed). Audit row: `action_taken='kind_bounce', outcome='ESCALATE'`. **Manual recovery required** — see "Manual kind-bounce" below. |

### Tier 2 observe-only toggle

Independent of the existing `/airbyte-auto-remediate/observe-only` flag (which
gates Tier 1 cancel+restart):

```bash
# Disable Tier 2 (kind-bounce stays in observe-only — log only, no bounce)
aws ssm put-parameter \
  --name /airbyte-auto-remediate/kind-bounce-observe-only \
  --value true --overwrite --profile ammodepot

# Enable live Tier 2 (after soak validates the trigger logic)
aws ssm put-parameter \
  --name /airbyte-auto-remediate/kind-bounce-observe-only \
  --value false --overwrite --profile ammodepot
```

Tier 1 cancel+restart continues running regardless — this flag only gates the
control-plane bounce.

### Reset the global kind-bounce cooldown

Tier 2 has a global 6h cooldown stored in DynamoDB under partition-key
`_GLOBAL_KIND_BOUNCE`. Reset it to allow an immediate retry:

```bash
aws dynamodb delete-item \
  --table-name airbyte-auto-remediate-state \
  --key '{"connection_id": {"S": "_GLOBAL_KIND_BOUNCE"}}' \
  --profile ammodepot
```

### Manual kind-bounce (when Tier 2 escalates)

If `[Airbyte KIND-BOUNCE ESCALATE]` fires, the automated bounce either failed
SSM execution or didn't recover the connection. Manual procedure:

```bash
# 1. Restart the control plane
aws ssm send-command \
  --instance-ids i-075043415ebad732f \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["sudo docker restart airbyte-abctl-control-plane"]' \
  --profile ammodepot

# 2. Wait ~3 min for pods to reschedule, then verify API readiness
aws ssm send-command \
  --instance-ids i-075043415ebad732f \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["curl -sS http://localhost:8000/api/v1/health"]' \
  --profile ammodepot

# 3. Check Snowflake freshness 5-10 min later (via dbt show or Snowsight)
# SELECT * FROM AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS;
```

If `docker restart` itself fails or the API doesn't come back, escalate to a
full Airbyte restart (`sudo systemctl restart abctl` or EC2 reboot — see
Phase 1 runbook).

## See also

- Phase 1 (detection-only) runbook: [`AIRBYTE_INCIDENT_RUNBOOK.md`](AIRBYTE_INCIDENT_RUNBOOK.md)
- Lambda README: [`../lambda/airbyte_auto_remediate/README.md`](../lambda/airbyte_auto_remediate/README.md)
- DESIGN (Phase 2): [`.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md`](../.claude/sdd/features/DESIGN_AIRBYTE_AUTO_REMEDIATION.md)
- DESIGN (Phase 2.1 kind-bounce): [`.claude/sdd/features/DESIGN_AIRBYTE_KIND_BOUNCE_TIER.md`](../.claude/sdd/features/DESIGN_AIRBYTE_KIND_BOUNCE_TIER.md)
- ClickUp task: [86ah8bpmj](https://app.clickup.com/t/86ah8bpmj)
