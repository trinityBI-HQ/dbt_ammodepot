# Airbyte EC2 Maintenance Guide

## Infrastructure Overview

| Component | Details |
|---|---|
| EC2 Instance | `ip-10-0-1-105` |
| Disk | 600GB EBS (`/dev/nvme0n1p1`) |
| Runtime | Kind (Kubernetes in Docker) |
| Container | `airbyte-abctl-control-plane` |
| Airbyte Version | 1.5.1 |
| Data Path (host) | `/opt/dbt/.airbyte/abctl/data/` |
| Data Path (container) | `/var/local-path-provisioner/` |
| Slack Webhook | Configured in Airbyte (notifications on sync failure) |

### Disk Usage Breakdown

With 65 active streams (35 Fishbowl + 30 Magento), Airbyte generates approximately:

| Component | Growth Rate | Location (container) |
|---|---|---|
| Minio job logs | ~26 GB/month | `/var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging/` |
| PostgreSQL (`attempts` table) | ~22 GB/month | `/var/local-path-provisioner/airbyte-volume-db/` |
| Other (workload, state, etc.) | ~2 GB/month | Various |
| **Total growth** | **~50 GB/month** | |

Without cleanup, the 600GB disk fills in approximately 12 months.

---

## Incident: Disk Full (2026-03-06)

### Symptoms
- Airbyte syncs failing silently
- `airbyte-server` pod: 2,251 restarts
- `kube-controller-manager`: 4,587 restarts
- Connection auto-disabled by Airbyte
- Server logs: `IdNotFoundKnownException: Could not find attempt stats`

### Root Cause
Disk at 99% (595GB / 600GB used). Never pruned in 334 days of operation:
- **Minio job-logging**: 290GB (sync stdout/stderr logs)
- **PostgreSQL `attempts` table**: 250GB (155,936 rows of sync attempt data)

### Resolution
1. Deleted Minio job logs: `rm -rf` on job-logging directory (freed 290GB)
2. Deleted old DB records: `DELETE FROM attempts/jobs WHERE created_at < NOW() - INTERVAL '14 days'`
3. Ran `VACUUM FULL` on all large tables (reclaimed 236GB in PostgreSQL)
4. Restarted all Airbyte pods: `kubectl rollout restart deployment -n airbyte-abctl`
5. Re-enabled disabled connection in Airbyte UI

**Result**: Disk usage dropped from 99% (595GB) to 13% (75GB).

---

## Monthly Cleanup Script

### `/opt/scripts/airbyte-cleanup.sh`

```bash
#!/bin/bash
# Airbyte monthly cleanup — run on 1st of each month at 3am
# Retains 30 days of history, sends Slack notification

SLACK_WEBHOOK="$SLACK_WEBHOOK"  # Set in environment or replace with your webhook URL
DAYS=30
CONTAINER="airbyte-abctl-control-plane"
NAMESPACE="airbyte-abctl"

# Report disk usage before cleanup
BEFORE=$(docker exec $CONTAINER df / --output=pcent | tail -1 | tr -dc '0-9')

echo "$(date) — Starting Airbyte cleanup (retaining ${DAYS} days)"

# 1. Clean Minio job logs older than 30 days
echo "Cleaning Minio job logs..."
docker exec $CONTAINER find \
  /var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging/workspace/ \
  -mindepth 1 -maxdepth 1 -mtime +${DAYS} -exec rm -rf {} +

# 2. Clean dependent DB tables first (foreign keys reference attempts)
echo "Cleaning database records..."
for table in stream_attempt_metadata stream_stats sync_stats; do
  docker exec $CONTAINER kubectl exec -n $NAMESPACE airbyte-db-0 -- \
    psql -U airbyte -d db-airbyte -c \
    "DELETE FROM ${table} WHERE attempt_id IN (SELECT id FROM attempts WHERE created_at < NOW() - INTERVAL '${DAYS} days');"
done

# 3. Clean attempts table
docker exec $CONTAINER kubectl exec -n $NAMESPACE airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c \
  "DELETE FROM attempts WHERE created_at < NOW() - INTERVAL '${DAYS} days';"

# 4. Clean jobs table
docker exec $CONTAINER kubectl exec -n $NAMESPACE airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c \
  "DELETE FROM jobs WHERE created_at < NOW() - INTERVAL '${DAYS} days';"

# 5. VACUUM to reclaim space (regular VACUUM, not FULL — less disruptive)
echo "Running VACUUM..."
docker exec $CONTAINER kubectl exec -n $NAMESPACE airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM attempts;"
docker exec $CONTAINER kubectl exec -n $NAMESPACE airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM jobs;"

# Report disk usage after cleanup
AFTER=$(docker exec $CONTAINER df / --output=pcent | tail -1 | tr -dc '0-9')

echo "$(date) — Cleanup complete. Disk: ${BEFORE}% -> ${AFTER}%"

# Send Slack notification
curl -s -X POST "$SLACK_WEBHOOK" -H 'Content-type: application/json' \
  -d "{\"text\":\"Airbyte monthly cleanup complete\nDisk: ${BEFORE}% -> ${AFTER}%\nRetained last ${DAYS} days\"}"
```

### Cron Setup

```bash
# Make script executable
sudo chmod +x /opt/scripts/airbyte-cleanup.sh

# Add monthly cron (1st of month at 3am UTC)
(crontab -l 2>/dev/null; echo "0 3 1 * * /opt/scripts/airbyte-cleanup.sh >> /var/log/airbyte-cleanup.log 2>&1") | sudo crontab -

# Verify
crontab -l
```

---

## Disk Alert Script

### `/opt/scripts/disk-alert.sh`

```bash
#!/bin/bash
# Disk usage alert — run every 6 hours
# Sends Slack alert if disk exceeds 70%

SLACK_WEBHOOK="$SLACK_WEBHOOK"  # Set in environment or replace with your webhook URL
THRESHOLD=70

DISK_PCT=$(df / --output=pcent | tail -1 | tr -dc '0-9')

if [ "$DISK_PCT" -ge "$THRESHOLD" ]; then
  # Get top space consumers for context
  TOP_USAGE=$(docker exec airbyte-abctl-control-plane du -d 1 -h /var/local-path-provisioner/ 2>/dev/null | sort -rh | head -5)

  curl -s -X POST "$SLACK_WEBHOOK" -H 'Content-type: application/json' \
    -d "{\"text\":\"Warning: Airbyte EC2 disk at ${DISK_PCT}%\nTop consumers:\n\`\`\`${TOP_USAGE}\`\`\`\nInvestigate before next monthly cleanup.\"}"
fi
```

### Cron Setup

```bash
sudo chmod +x /opt/scripts/disk-alert.sh

# Run every 6 hours
(crontab -l 2>/dev/null; echo "0 */6 * * * /opt/scripts/disk-alert.sh") | sudo crontab -
```

---

## Manual Diagnostic Commands

### Check Disk Usage

```bash
# Host disk
df -h /

# Inside Kind container
docker exec -it airbyte-abctl-control-plane df -h /

# Breakdown by component
docker exec -it airbyte-abctl-control-plane du -sh /var/local-path-provisioner/airbyte-minio-pv/ 2>/dev/null
docker exec -it airbyte-abctl-control-plane du -sh /var/local-path-provisioner/airbyte-volume-db/ 2>/dev/null

# Minio sub-directories
docker exec -it airbyte-abctl-control-plane du -d 2 -h /var/local-path-provisioner/airbyte-minio-pv/ 2>/dev/null | sort -rh | head -10
```

### Check PostgreSQL Table Sizes

```bash
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c \
  "SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS size
   FROM pg_class WHERE relkind='r'
   ORDER BY pg_total_relation_size(oid) DESC LIMIT 10;"
```

### Check Record Counts and Date Range

```bash
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c \
  "SELECT count(*), min(created_at), max(created_at) FROM attempts;"

docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c \
  "SELECT count(*), min(created_at), max(created_at) FROM jobs;"
```

### Check Pod Health

```bash
# All pods
docker exec -it airbyte-abctl-control-plane kubectl get pods -A

# Recent events (look for OOMKilled, Evicted, FailedScheduling)
docker exec -it airbyte-abctl-control-plane kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# Server logs
docker exec -it airbyte-abctl-control-plane kubectl logs -n airbyte-abctl deploy/airbyte-abctl-server --tail=50

# Resource usage inside Kind
docker exec -it airbyte-abctl-control-plane top -bn1 | head -15
```

### Restart Airbyte (After Maintenance)

```bash
# Restart all deployments (graceful)
docker exec -it airbyte-abctl-control-plane kubectl rollout restart deployment -n airbyte-abctl

# Check status after 30 seconds
sleep 30 && docker exec -it airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
```

---

## Emergency: Disk Full Recovery Procedure

If the disk reaches 95%+ and Airbyte stops working:

### Step 1: Free Minio Logs (Immediate — safe to delete)

```bash
# Delete all job logs (recovers the most space fastest)
docker exec -it airbyte-abctl-control-plane rm -rf \
  /var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging
docker exec -it airbyte-abctl-control-plane mkdir -p \
  /var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging
docker exec -it airbyte-abctl-control-plane chown 1000:1000 \
  /var/local-path-provisioner/airbyte-minio-pv/airbyte-storage/job-logging

# Restart Minio to release file handles
docker exec -it airbyte-abctl-control-plane kubectl delete pod -n airbyte-abctl airbyte-minio-0
```

### Step 2: Prune Database (After disk has space)

```bash
# Delete dependent tables first
for table in stream_attempt_metadata stream_stats sync_stats; do
  docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
    psql -U airbyte -d db-airbyte -c \
    "DELETE FROM ${table} WHERE attempt_id IN (SELECT id FROM attempts WHERE created_at < NOW() - INTERVAL '14 days');"
done

# Delete attempts and jobs
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "DELETE FROM attempts WHERE created_at < NOW() - INTERVAL '14 days';"
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "DELETE FROM jobs WHERE created_at < NOW() - INTERVAL '14 days';"
```

### Step 3: Reclaim PostgreSQL Disk Space

```bash
# VACUUM FULL rewrites the table — needs free disk ~= new table size
# Only run after Step 1 has freed sufficient space
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM FULL attempts;"
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM FULL jobs;"
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM FULL stream_attempt_metadata;"
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM FULL stream_stats;"
docker exec -it airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "VACUUM FULL sync_stats;"
```

**Important**: If VACUUM FULL fails with "No space left on device", free more Minio data first. VACUUM FULL needs temporary space roughly equal to the new (compacted) table size.

### Step 4: Restart and Re-enable

```bash
# Restart all pods
docker exec -it airbyte-abctl-control-plane kubectl rollout restart deployment -n airbyte-abctl

# Check pod health
sleep 30 && docker exec -it airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl
```

Then open the Airbyte UI (`http://<EC2-IP>:8000`) and re-enable any auto-disabled connections.

---

## Notes

- **EBS volumes cannot be shrunk** — only increased. The 600GB disk is sufficient with monthly cleanup.
- **VACUUM vs VACUUM FULL**: Regular `VACUUM` marks space as reusable but doesn't shrink the file on disk. `VACUUM FULL` rewrites the table and returns space to the OS, but locks the table and needs temporary disk space.
- **kubectl is not installed on the EC2 host** — all K8s commands run via `docker exec` into the Kind container.
- **Kubeconfig path**: `~/.airbyte/abctl/abctl.kubeconfig` (if kubectl is installed later).
- **Airbyte auto-disables connections** after repeated sync failures — check the UI after recovery.
