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
| Logs | `/var/log/airbyte-cleanup.log`, `/var/log/disk-alert.log` |

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

Source: [`scripts/airbyte-cleanup.sh`](../scripts/airbyte-cleanup.sh) — deployed to `/opt/scripts/airbyte-cleanup.sh` on EC2.

**What it does:**
1. Deletes Minio job logs older than 30 days
2. Deletes dependent DB rows (`stream_attempt_metadata`, `stream_stats`, `sync_stats`)
3. Deletes `attempts` and `jobs` rows older than 30 days
4. Runs `VACUUM` on all cleaned tables (regular, not FULL)
5. Reports disk usage before/after and sends Slack notification

**Features:**
- `--dry-run` mode to preview without deleting
- `RETENTION_DAYS` env var to override 30-day default
- Pre-flight check (verifies Docker container is running)
- Row counts logged for each table

**Cron schedule:** 1st of month at 3:00 AM UTC

---

## Disk Alert Script

Source: [`scripts/disk-alert.sh`](../scripts/disk-alert.sh) — deployed to `/opt/scripts/disk-alert.sh` on EC2.

**What it does:**
- Checks host disk usage against threshold (default 70%)
- If exceeded, sends Slack alert with top disk consumers and DB table sizes
- Exits silently when disk is healthy

**Cron schedule:** Every 6 hours

---

## Deployment

Source: [`scripts/deploy.sh`](../scripts/deploy.sh) — run once on the EC2 instance to install everything.

```bash
# 1. Copy scripts to EC2
scp -r scripts/ ec2-user@<EC2-IP>:/tmp/airbyte-scripts/

# 2. SSH into EC2 and run installer
ssh ec2-user@<EC2-IP>
cd /tmp/airbyte-scripts
sudo ./deploy.sh

# 3. Verify with dry run
sudo /opt/scripts/airbyte-cleanup.sh --dry-run

# 4. (Optional) Run first cleanup immediately
sudo /opt/scripts/airbyte-cleanup.sh
```

The installer:
- Copies scripts to `/opt/scripts/`
- Prompts for Slack webhook URL (saves to `/etc/environment`)
- Sets up both cron jobs (deduplicates if run again)
- Runs a dry-run test to verify connectivity

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
