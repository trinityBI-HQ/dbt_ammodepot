# Airbyte Incident Runbook

**Target:** First-time operator can complete cancel + restart in 5 minutes following only this document.

**When to use this:** You received a `[Airbyte WARN]` or `[Airbyte ALERT]` email from `victor@trinitybi.com`.

---

## Step 1 — Confirm staleness on the dashboard (1 min)

1. Open Snowsight → **Streamlit Apps** → `AD_ANALYTICS.OPS.INFRA_MONITOR`
2. Click the **Airbyte Health** tab (Page 6)
3. Note which connection is yellow (WARN) or red (ALERT): `fishbowl_s3` and/or `magento_s3`
4. Note the "oldest stream" name from the per-stream table — that is the likely culprit

If both connections are red: Airbyte itself is likely down, not a single stream issue.
If only one connection is red: a single Fishbowl or Magento sync is stuck.

---

## Step 2 — Open an SSM shell on the Airbyte EC2 (1 min)

The Airbyte EC2 has no public SSH access. Use AWS SSM Session Manager.

```bash
aws ssm start-session \
    --target i-075043415ebad732f \
    --profile ammodepot
```

This drops you into a bash shell on the EC2 instance as `ssm-user`.

**Prerequisites on your laptop:**
- AWS CLI installed and `~/.aws/credentials` has the `ammodepot` profile (`svc_iac` key)
- Session Manager plugin installed: `aws ssm start-session` fails with `SessionManagerPlugin is not found` if not. Install from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

---

## Step 3 — Check Airbyte pod and job status (1 min)

Once inside the SSM shell:

```bash
# Check overall Airbyte pod health
kubectl get pods -n airbyte-abctl

# Look for pods in Error, CrashLoopBackOff, or Pending state
# A running replication pod looks like: airbyte-worker-xxx   Running
```

To check active Airbyte jobs via the API (Airbyte 2.0 runs on port 8006 inside the cluster):

```bash
# Port-forward Airbyte API to localhost (run in background)
kubectl port-forward svc/airbyte-abctl-airbyte-server 8006:8006 -n airbyte-abctl &

# List all running jobs
curl -s http://localhost:8006/api/v1/jobs \
    -H "Content-Type: application/json" \
    -d '{"configTypes":["sync"],"configId":"<TBD: connection ID>"}' \
    | python3 -m json.tool
```

**Shell-escape gotchas specific to this Airbyte 2.0 / abctl setup:**

1. **Glob expansion (`*`):** The shell expands `*` in `kubectl get pods *` — always quote or avoid wildcards in kubectl commands. Use `-n airbyte-abctl` explicitly rather than namespace wildcards.

2. **Pipe parser (`|`):** When piping `curl` output into `python3`, the shell may split on `|` if your SSM session has a non-standard PS1. Use a temp file if the pipe breaks:
   ```bash
   curl -s http://localhost:8006/api/v1/jobs \
       -H "Content-Type: application/json" \
       -d '{"configTypes":["sync"]}' \
       > /tmp/jobs.json
   cat /tmp/jobs.json | python3 -m json.tool
   ```

3. **abctl vs kubectl:** This instance uses `abctl` (Airbyte's k8s wrapper). For most operations `kubectl` works directly because `abctl` bootstrapped a `kind` cluster. If `kubectl` is not in PATH, use: `/usr/local/bin/kubectl` or `abctl kubectl`.

---

## Step 4 — Identify the stuck job (30 sec)

```bash
# List recent sync jobs for all connections (no connection-ID filter)
curl -s http://localhost:8006/api/v1/jobs \
    -H "Content-Type: application/json" \
    -d '{"configTypes":["sync"],"status":"running"}' \
    > /tmp/running_jobs.json
cat /tmp/running_jobs.json | python3 -m json.tool | grep -E '"id"|"status"|"configId"'
```

Note the `id` (job ID) of the stuck job. You will need it in Step 5.

**Connection IDs** (Airbyte internal UUIDs — needed for per-connection API calls):

| Connection | Airbyte Connection ID |
|------------|-----------------------|
| Fishbowl → S3 Iceberg | `<TBD: run SHOW CONNECTIONS in Airbyte UI or GET /v1/connections>` |
| Magento → S3 Iceberg | `<TBD: run SHOW CONNECTIONS in Airbyte UI or GET /v1/connections>` |

To look up the correct IDs:
```bash
curl -s http://localhost:8006/api/v1/connections \
    -H "Content-Type: application/json" \
    -d '{"workspaceId":"<workspace-id>"}' \
    | python3 -m json.tool | grep -E '"connectionId"|"name"'
```

> **Note for connection ID resolution:** The CLAUDE.md memory `reference_airbyte_api_ssm.md` was not found on disk at the time this runbook was authored. Run the `GET /v1/connections` command above from an SSM shell to retrieve the current connection IDs, then update this table. The workspace ID is shown on the Airbyte UI home page (URL: `http://<EC2-EIP>:8000/workspaces`). EC2 EIP is `18.204.90.52`.

---

## Step 5 — Cancel the stuck job (30 sec)

```bash
# Cancel job by job ID (from Step 4)
curl -s -X DELETE http://localhost:8006/api/v1/jobs/<job_id> \
    -H "Content-Type: application/json"

# Confirm the job is gone
curl -s http://localhost:8006/api/v1/jobs/<job_id> \
    -H "Content-Type: application/json" \
    | python3 -m json.tool | grep '"status"'
# Expected: "status": "cancelled"
```

If the `DELETE` returns 404 or the pod refuses to terminate, force-delete the replication pod:

```bash
kubectl get pods -n airbyte-abctl | grep -i replication
kubectl delete pod <pod-name> -n airbyte-abctl --grace-period=0 --force
```

---

## Step 6 — Trigger a fresh sync (30 sec)

```bash
# Start a new sync for the affected connection
curl -s -X POST http://localhost:8006/api/v1/connections/sync \
    -H "Content-Type: application/json" \
    -d '{"connectionId":"<TBD: connection ID from Step 4>"}'
# Expected response: {"job":{"id":..., "status":"pending"}}
```

Monitor until the sync reaches `running`:
```bash
# Check status every 30 seconds
watch -n 30 "curl -s http://localhost:8006/api/v1/jobs \
    -H 'Content-Type: application/json' \
    -d '{\"configTypes\":[\"sync\"],\"status\":\"running\"}' \
    | python3 -m json.tool | grep '\"status\"'"
```

Press `Ctrl+C` when you see `"status": "succeeded"` or the job disappears from the running list.

---

## Step 7 — Verify recovery on the dashboard (1 min)

1. Return to the Streamlit Infra Monitor → **Airbyte Health** tab
2. Wait up to 2 minutes for the view cache to refresh (TTL = 1 min)
3. The KPI card for the affected connection should turn green (`OK`)
4. The `oldest_staleness_min` should reset to ≤15 min

If the card stays red after a successful sync, the Iceberg metadata has not refreshed yet. The ECS refresh sidecar runs ahead of each dbt build (`cron 5,20,35,50`). Wait for the next refresh cycle (up to 15 min) and recheck.

---

## When to escalate

| Symptom | Action |
|---------|--------|
| Cancel succeeds but restart fails with `400 Bad Request` | Check Airbyte source/destination connector health in the Airbyte UI (`http://18.204.90.52:8000`). The connector may have lost credentials. |
| Multiple cancel-restart cycles needed (3+) | Check EC2 disk space: `df -h`. Airbyte logs fill `/var/lib/airbyte` quickly. Run `/opt/scripts/airbyte-cleanup.sh --dry-run` to preview cleanup. |
| Both connections stuck simultaneously | Likely Airbyte platform issue. Restart the Airbyte server pod: `kubectl rollout restart deployment/airbyte-abctl-server -n airbyte-abctl` |
| Data older than 6 hours | Escalate to Victor at trinity@trinitybi.com — this may indicate S3 write permission issues or Glue catalog problems, not just a stuck sync |
| EC2 instance unreachable via SSM | Check EC2 console: `aws ec2 describe-instance-status --instance-ids i-075043415ebad732f --profile ammodepot`. If stopped, start it. |

---

## Quick reference

| Item | Value |
|------|-------|
| EC2 Instance ID | `i-075043415ebad732f` |
| EC2 Instance Type | c6a.2xlarge (8 vCPU, 16 GB) |
| EC2 EIP | `18.204.90.52` |
| Airbyte Version | v2.0.1 (Chart 2.0.19), abctl v0.30.4 |
| Kubernetes | `kind` cluster managed by `abctl` |
| Airbyte API Port | 8006 (internal, port-forward from SSM) |
| AWS Profile | `ammodepot` (svc_iac credentials) |
| Cleanup script | `/opt/scripts/airbyte-cleanup.sh` |
| Cleanup log | `/var/log/airbyte-cleanup.log` |
| Disk alert log | `/var/log/disk-alert.log` |
| Freshness dashboard | AD_ANALYTICS.OPS.INFRA_MONITOR → Airbyte Health tab |
| Email alert sender | OPS_EMAIL_NOTIFICATIONS (Snowflake integration) |
| Alert objects | ALERT_AIRBYTE_FRESHNESS_WARN, ALERT_AIRBYTE_FRESHNESS_ALERT |
| Suspend an alert | `ALTER ALERT ad_analytics.ops.alert_airbyte_freshness_warn SUSPEND;` |
| Resume an alert | `ALTER ALERT ad_analytics.ops.alert_airbyte_freshness_warn RESUME;` |
