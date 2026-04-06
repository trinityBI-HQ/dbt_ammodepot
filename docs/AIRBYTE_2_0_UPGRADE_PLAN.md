# Airbyte 2.0 Upgrade Plan

**Current Version:** 1.5.1 (abctl-managed, kind/k8s)
**Target Version:** 2.0.x (ships with abctl v0.30.4+)
**Instance:** EC2 c6a.2xlarge (8 vCPU, 16 GB), `ip-10-0-1-105`
**Date Created:** 2026-04-06
**Status:** Planning

---

## Background

### Failed Upgrade Attempt (April 2026)

An upgrade to Airbyte 2.0.1 via `abctl local install` (abctl v0.30.4) was attempted and failed:

1. The 2.0 bootloader modified Kubernetes resources in-place before deploying new pods:
   - **Removed** `WEBAPP_URL` from ConfigMap `airbyte-abctl-airbyte-env`
   - **Removed** `WORKLOAD_API_BEARER_TOKEN` from Secret `airbyte-abctl-airbyte-secrets`
2. Existing 1.5.1 pods (still running, not yet replaced) referenced these keys and began crash-looping
3. The Helm release status was left in a `failed` state
4. Rollback was performed by restoring the ConfigMap/Secret values, which allowed existing 1.5.1 pods to recover

**Key finding:** Helm is NOT installed inside the kind container -- abctl manages Helm externally on the host. This means manual Helm commands inside the container will not work.

### Active Connections (4 total)

| # | Connection | Destination | Frequency | Streams | Impact of Downtime |
|---|---|---|---|---|---|
| 1 | Fishbowl -> Snowflake | Snowflake | 10-min cron | 35 | Data staleness in BI dashboards |
| 2 | Magento -> Snowflake | Snowflake | 10-min cron | 29 | Data staleness in BI dashboards |
| 3 | Fishbowl -> S3 Iceberg | S3 | Manual | 34 | No impact (manual trigger) |
| 4 | Magento -> S3 Iceberg | S3 | Manual | 21 | No impact (manual trigger) |

---

## 1. Pre-Upgrade Checklist

### 1a. Export Connection State and Configuration

```bash
# SSH into EC2 via Session Manager
# Export all connection configurations via API
curl -s http://localhost:8000/api/v1/connections/list \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.' > /tmp/airbyte-connections-backup.json

# Export source definitions
curl -s http://localhost:8000/api/v1/sources/list \
  -H "Content-Type: application/json" \
  -d '{"workspaceId": "<workspace-id>"}' | jq '.' > /tmp/airbyte-sources-backup.json

# Export destination definitions
curl -s http://localhost:8000/api/v1/destinations/list \
  -H "Content-Type: application/json" \
  -d '{"workspaceId": "<workspace-id>"}' | jq '.' > /tmp/airbyte-destinations-backup.json

# Export workspace settings
curl -s http://localhost:8000/api/v1/workspaces/list \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.' > /tmp/airbyte-workspaces-backup.json
```

### 1b. Backup Kubernetes Resources

```bash
CONTAINER="airbyte-abctl-control-plane"
NS="airbyte-abctl"

# Backup all ConfigMaps
docker exec $CONTAINER kubectl get configmap -n $NS -o yaml > /tmp/airbyte-configmaps-backup.yaml

# Backup all Secrets (base64-encoded values)
docker exec $CONTAINER kubectl get secrets -n $NS -o yaml > /tmp/airbyte-secrets-backup.yaml

# Backup all deployments/statefulsets
docker exec $CONTAINER kubectl get deployments,statefulsets -n $NS -o yaml > /tmp/airbyte-workloads-backup.yaml

# Backup PVCs (persistent volume claims)
docker exec $CONTAINER kubectl get pvc -n $NS -o yaml > /tmp/airbyte-pvcs-backup.yaml

# Snapshot running pod state
docker exec $CONTAINER kubectl get pods -n $NS -o wide > /tmp/airbyte-pods-before.txt
```

### 1c. Backup Airbyte Internal Database

```bash
# Full pg_dump of the Airbyte metadata database
docker exec $CONTAINER kubectl exec -n $NS airbyte-db-0 -- \
  pg_dump -U airbyte -d db-airbyte --format=custom \
  -f /tmp/db-airbyte-backup.dump

# Copy dump out of the kind container
docker cp $CONTAINER:/tmp/db-airbyte-backup.dump /tmp/airbyte-db-backup.dump
```

### 1d. Copy Backups to S3

```bash
# Upload all backups to S3 for disaster recovery
aws s3 cp /tmp/airbyte-connections-backup.json \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-sources-backup.json \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-destinations-backup.json \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-workspaces-backup.json \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-configmaps-backup.yaml \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-secrets-backup.yaml \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-workloads-backup.yaml \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
aws s3 cp /tmp/airbyte-db-backup.dump \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
```

### 1e. Verify Current State is Healthy

```bash
# Confirm all pods are Running (not CrashLoopBackOff)
docker exec $CONTAINER kubectl get pods -n $NS

# Confirm all 4 connections are syncing successfully
# Check via Airbyte UI at http://localhost:8000

# Confirm Helm release state (may still show "failed" from prior attempt)
# abctl manages Helm externally, so check from the host:
abctl local status

# Run a manual sync on each connection and verify completion
```

### 1f. Document Current Versions

```bash
# Record exact versions for rollback reference
abctl version
docker exec $CONTAINER kubectl get pods -n $NS -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

### 1g. Fix Helm Release State (Critical)

The previous failed upgrade left the Helm release in a `failed` state. This MUST be resolved before attempting the upgrade again, or `abctl local install` may behave unpredictably.

```bash
# Option A: Use abctl to reconcile (preferred)
# Downgrade abctl back to the version that matches 1.5.1 first
# Then run install to reset Helm release to a clean "deployed" state
abctl local install

# Option B: If abctl cannot fix the Helm state, uninstall and reinstall
# (see Rollback Plan section for full procedure)
```

---

## 2. Maintenance Window Requirements

### Duration

| Phase | Estimated Time | Notes |
|---|---|---|
| Pre-upgrade backups | 15 min | Can be done ahead of window |
| Disable connections | 5 min | Pause all 4 connections in UI |
| Upgrade execution | 15-30 min | `abctl local install` pulls new images |
| Pod stabilization | 10-15 min | Wait for all pods to reach Running |
| Post-upgrade validation | 15-20 min | Test syncs, verify data |
| **Total window** | **45-90 min** | |

### What is Affected

- **Snowflake data freshness**: Fishbowl and Magento syncs will pause. BI dashboards will show stale data (up to 90 min behind). dbt runs (every 10 min on ECS Fargate) will continue but will process stale source data.
- **S3 Iceberg connections**: No impact (manual trigger only).
- **Power BI dashboards**: Will continue to query Snowflake but with stale underlying data.
- **dbt ECS Fargate**: No changes needed. Will resume normal operation once syncs recover.

### Recommended Timing

- **Weekend or evening** (low BI usage)
- **Avoid month-end** (higher reporting demand)
- **Notify stakeholders** that dashboards may be 1-2 hours behind during the window

---

## 3. Step-by-Step Upgrade Procedure

### Step 0: Enter Maintenance Mode

```bash
# Connect to EC2 via Session Manager
# Disable all 4 connections in Airbyte UI (http://localhost:8000)
# Wait for any in-progress syncs to complete (check Jobs page)
```

### Step 1: Verify Backups are Complete

```bash
# Confirm all backup files exist in S3
aws s3 ls s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
```

### Step 2: Snapshot the Kind Container (Safety Net)

```bash
# Create a Docker commit of the kind container as a restore point
docker commit airbyte-abctl-control-plane airbyte-abctl-snapshot:pre-2.0
docker save airbyte-abctl-snapshot:pre-2.0 | gzip > /tmp/airbyte-kind-snapshot.tar.gz

# Optional: upload to S3
aws s3 cp /tmp/airbyte-kind-snapshot.tar.gz \
  s3://ammodepot-lakehouse/backups/airbyte/2026-04-XX/ --profile ammodepot
```

### Step 3: Upgrade abctl to the Target Version

```bash
# Install the specific abctl version that ships Airbyte 2.0.x
curl -sSL https://get.airbyte.com | bash
# Or pin a specific version:
# curl -sSL https://get.airbyte.com | bash -s -- --version v0.30.4

# Verify
abctl version
```

### Step 4: Pre-stage Container Images (Reduce Downtime)

```bash
# Pull the 2.0 images into the kind container before running upgrade
# This reduces the actual upgrade time significantly
# Check abctl release notes for exact image tags, then:
docker exec airbyte-abctl-control-plane crictl pull docker.io/airbyte/webapp:2.0.1
docker exec airbyte-abctl-control-plane crictl pull docker.io/airbyte/server:2.0.1
docker exec airbyte-abctl-control-plane crictl pull docker.io/airbyte/worker:2.0.1
# (add other images as listed in the 2.0 release manifest)
```

### Step 5: Run the Upgrade

```bash
# Run abctl local install — this triggers the Helm upgrade
abctl local install 2>&1 | tee /tmp/airbyte-upgrade.log
```

**Monitor closely for:**
- ConfigMap/Secret modifications (the root cause of the previous failure)
- Pod startup errors
- Database migration output

### Step 6: Monitor Pod Startup

```bash
# Watch pods come up (run in a separate terminal)
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl -w

# Check for CrashLoopBackOff or Error states
# If any pod is stuck, check its logs:
docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl <pod-name> --tail=100
```

### Step 7: Verify the Upgrade

```bash
# Confirm abctl reports the new version
abctl local status

# Confirm all pods are Running
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl

# Confirm the UI loads at http://localhost:8000
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000
```

### Step 8: Re-enable Connections and Test

```bash
# Re-enable all 4 connections in the Airbyte UI
# Trigger a manual sync on each connection
# Monitor the Jobs page for successful completion
```

---

## 4. Rollback Plan

### Scenario A: Upgrade Fails Mid-Way (Same as Previous Failure)

If `abctl local install` fails and pods are crash-looping due to missing ConfigMap/Secret keys:

```bash
NS="airbyte-abctl"
CONTAINER="airbyte-abctl-control-plane"

# 1. Check what changed
docker exec $CONTAINER kubectl get configmap airbyte-abctl-airbyte-env -n $NS -o yaml
docker exec $CONTAINER kubectl get secret airbyte-abctl-airbyte-secrets -n $NS -o yaml

# 2. Restore ConfigMap values from backup
docker exec $CONTAINER kubectl apply -f /tmp/airbyte-configmaps-backup.yaml

# 3. Restore Secret values from backup
docker exec $CONTAINER kubectl apply -f /tmp/airbyte-secrets-backup.yaml

# 4. Restart all deployments to pick up restored values
docker exec $CONTAINER kubectl rollout restart deployment -n $NS

# 5. Wait for pods to stabilize
docker exec $CONTAINER kubectl get pods -n $NS -w
```

### Scenario B: Upgrade Completes But Data is Corrupted or Connections Broken

```bash
# 1. Downgrade abctl to the version that ships 1.5.1
# Find the old abctl binary version (check /usr/local/bin/abctl.bak if you backed it up)
# Or download a specific older abctl release from GitHub

# 2. Restore the database from backup
docker cp /tmp/airbyte-db-backup.dump $CONTAINER:/tmp/
docker exec $CONTAINER kubectl exec -n $NS airbyte-db-0 -- \
  pg_restore -U airbyte -d db-airbyte --clean --if-exists /tmp/db-airbyte-backup.dump

# 3. Reinstall with the old abctl version
abctl local install
```

### Scenario C: Nuclear Option (Full Rebuild from Snapshot)

If the kind container is irrecoverable:

```bash
# 1. Stop the current kind cluster
abctl local uninstall

# 2. Restore from Docker snapshot
docker load < /tmp/airbyte-kind-snapshot.tar.gz
# Recreate the kind cluster using the snapshot
# (This is complex — document the exact steps when testing)

# 3. Alternative: Fresh install and re-import
abctl local install  # with old abctl version
# Re-create connections from the JSON backups exported in Step 1a
# NOTE: This will lose sync state (cursor positions) — full refresh required
```

### Scenario D: Fresh Install with Connection Re-Creation

Last resort if all else fails:

```bash
# 1. Complete uninstall
abctl local uninstall --persisted

# 2. Fresh install of 1.5.1 (using old abctl version)
abctl local install

# 3. Re-create workspace, sources, destinations, and connections
# Use the JSON backups from Step 1a as reference
# All connections will need full initial sync (could take hours)
```

---

## 5. Post-Upgrade Validation

### 5a. System Health Checks

```bash
# All pods Running
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl

# No restart loops (RESTARTS column should be 0 or very low)
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl -o wide

# Airbyte API responding
curl -s http://localhost:8000/api/v1/health | jq '.'

# Database accessible
docker exec airbyte-abctl-control-plane kubectl exec -n airbyte-abctl airbyte-db-0 -- \
  psql -U airbyte -d db-airbyte -c "SELECT count(*) FROM jobs;"
```

### 5b. Connection Validation (All 4 Connections)

For each connection:

1. **Trigger a manual sync** from the Airbyte UI
2. **Verify sync completes** without errors in the Jobs page
3. **Verify record counts** — compare row counts in destination tables against pre-upgrade baseline
4. **Verify incremental state** — confirm CDC cursors were preserved (not starting from scratch)

### 5c. Snowflake Data Freshness

```sql
-- Run in Snowflake as TRANSFORMER_ROLE
USE ROLE TRANSFORMER_ROLE;
USE DATABASE AD_AIRBYTE;

-- Check freshness of key tables (should be within last 20 min after sync)
SELECT '_airbyte_extracted_at' AS col,
       MAX(_airbyte_extracted_at) AS latest,
       DATEDIFF('minute', MAX(_airbyte_extracted_at), CURRENT_TIMESTAMP()) AS minutes_ago
FROM AD_FISHBOWL.SO;

SELECT '_airbyte_extracted_at' AS col,
       MAX(_airbyte_extracted_at) AS latest,
       DATEDIFF('minute', MAX(_airbyte_extracted_at), CURRENT_TIMESTAMP()) AS minutes_ago
FROM AD_MAGENTO.SALES_ORDER;
```

### 5d. dbt Build Verification

```bash
# After Airbyte syncs resume, verify dbt builds still pass
# Check ECS Fargate CloudWatch logs
aws logs tail /ecs/ammodepot-dbt --since 30m --profile ammodepot
```

### 5e. Cleanup Scripts Still Work

```bash
# Verify the monthly cleanup script still works with the new DB schema
sudo /opt/scripts/airbyte-cleanup.sh --dry-run

# If the 2.0 schema changed table names (attempts, jobs, etc.),
# update airbyte-cleanup.sh accordingly
```

### 5f. Monitoring for 24 Hours Post-Upgrade

- Watch for sync failures in Airbyte UI
- Monitor ECS dbt build logs for data quality test failures
- Check Power BI dashboards for data gaps
- Monitor EC2 disk usage (2.0 may have different storage patterns)

---

## 6. Known Breaking Changes in Airbyte 2.0 vs 1.5.1

### 6a. Confirmed from Failed Attempt

| Change | Impact | Mitigation |
|---|---|---|
| `WEBAPP_URL` removed from ConfigMap | Pods referencing this env var crash | 2.0 pods should not reference it; only a problem during mixed-version state |
| `WORKLOAD_API_BEARER_TOKEN` removed from Secret | Pods referencing this secret key crash | Same as above — transition issue |

### 6b. Expected Breaking Changes (Based on Airbyte 2.0 Release Notes)

| Area | Change | Impact |
|---|---|---|
| **API endpoints** | v1 API deprecated; v2 API is primary | Cleanup scripts using `/api/v1/` may need updates |
| **Connector protocol** | Protocol version bump | Some older connectors may need updates; check Fishbowl (MySQL CDC) and Magento (MySQL CDC) connector versions |
| **Database schema** | Internal metadata DB schema migration | `airbyte-cleanup.sh` may need table name updates if `attempts`, `jobs`, `stream_stats`, `sync_stats`, `stream_attempt_metadata` are renamed or restructured |
| **Helm chart structure** | Chart values restructured | Managed by abctl, but custom overrides (if any) may break |
| **Authentication** | New auth model (bearer tokens, etc.) | Check if API access patterns change |
| **Workload management** | New workload launcher architecture | May change how sync pods are scheduled — monitor resource usage |
| **Connector image registry** | Possible registry migration | Verify connectors can still be pulled from within kind |
| **Cron scheduling** | Scheduler may reset | Re-verify that 10-min cron is preserved on both Snowflake connections |
| **State management** | Cursor/state format changes | Incremental sync cursors should be migrated automatically, but verify |

### 6c. Items to Verify Before Upgrading

1. **Read the full Airbyte 2.0 changelog** at https://docs.airbyte.com/release_notes/
2. **Check connector compatibility** for:
   - `source-mysql` (Fishbowl CDC) — confirm version supports protocol v2
   - `source-mysql` (Magento CDC) — same
   - `destination-snowflake` — confirm version supports protocol v2
   - `destination-s3` (Iceberg) — confirm version supports protocol v2
3. **Check abctl release notes** for the specific version being installed
4. **Test in a non-production environment** if possible (see Risk Assessment)

---

## 7. Risk Assessment

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Repeat of ConfigMap/Secret removal causing crash loops | **High** | Medium | Pre-backup all K8s resources; have restore commands ready |
| Incremental sync state lost (full refresh required) | Medium | **High** | Backup state via API; verify cursor preservation post-upgrade |
| Connector version incompatibility | Medium | **High** | Check connector versions against 2.0 compatibility matrix before upgrading |
| Database migration failure | Low | **High** | Full pg_dump backup; tested restore procedure |
| Extended downtime beyond 90 min | Medium | Medium | Docker snapshot as nuclear rollback option; stakeholder notification |
| Cleanup scripts break on new DB schema | **High** | Low | Test `--dry-run` immediately post-upgrade; update table names if needed |
| 10-min cron schedules reset to default | Medium | Medium | Document current schedule; re-apply if needed post-upgrade |
| Disk space exhaustion during upgrade (image pulls) | Low | Medium | Pre-stage images; verify >20 GB free before starting |

### Overall Risk: MEDIUM-HIGH

The failed previous attempt demonstrates that the 2.0 upgrade path through abctl has rough edges. The core risk is the in-place modification of Kubernetes resources before replacing pods, which creates a window where running pods reference deleted config values.

### Recommendations

1. **Do NOT attempt the upgrade without the full backup procedure** described in Section 1
2. **Docker-commit the kind container** before upgrading (Step 2 in the procedure) -- this is the strongest rollback guarantee
3. **Consider waiting for abctl v0.31+** to see if the ConfigMap/Secret transition issue is fixed upstream
4. **Monitor Airbyte GitHub issues** for other users reporting 1.5 -> 2.0 upgrade failures via abctl
5. **Test on a throwaway EC2 instance** first if budget allows (~$5 for a few hours of c6a.2xlarge)
6. **Have a second person available** during the maintenance window to help troubleshoot

### Decision Criteria for Proceeding

Proceed with the upgrade when ALL of the following are true:

- [ ] Airbyte 2.0 changelog has been fully reviewed
- [ ] All 4 connector versions are confirmed compatible with 2.0
- [ ] abctl release notes confirm the ConfigMap/Secret transition issue is resolved (or a workaround exists)
- [ ] Full backup procedure (Section 1) has been completed and verified
- [ ] Docker snapshot of the kind container has been saved
- [ ] A test upgrade on a throwaway instance has succeeded (optional but strongly recommended)
- [ ] Stakeholders have been notified of the maintenance window
- [ ] The cleanup script (`airbyte-cleanup.sh`) has been reviewed against the 2.0 DB schema

---

## Appendix A: Quick Reference Commands

```bash
# Check current Airbyte version
abctl local status

# Check pod status
docker exec airbyte-abctl-control-plane kubectl get pods -n airbyte-abctl

# Check pod logs
docker exec airbyte-abctl-control-plane kubectl logs -n airbyte-abctl <pod> --tail=50

# Check ConfigMap
docker exec airbyte-abctl-control-plane kubectl get configmap airbyte-abctl-airbyte-env -n airbyte-abctl -o yaml

# Check Secrets (base64)
docker exec airbyte-abctl-control-plane kubectl get secret airbyte-abctl-airbyte-secrets -n airbyte-abctl -o yaml

# Restart all deployments
docker exec airbyte-abctl-control-plane kubectl rollout restart deployment -n airbyte-abctl

# Access Airbyte UI
# http://localhost:8000 (from EC2 via Session Manager port-forward)
```

## Appendix B: File Dependencies to Update Post-Upgrade

| File | What May Change |
|---|---|
| `airbyte-ec2/airbyte-cleanup.sh` | DB table names (`attempts`, `jobs`, `stream_stats`, etc.) if schema changed |
| `airbyte-ec2/disk-alert.sh` | Same DB query dependency |
| `.claude/CLAUDE.md` | Airbyte version reference (1.5.1 -> 2.0.x), abctl version |
| `docs/AIRBYTE_RESOURCE_OPTIMIZATION.md` | Version references if applicable |
