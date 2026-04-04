# Airbyte Resource Optimization

**Date:** 2026-04-01
**Status:** Planned (apply after S3 Lakehouse extraction completes)
**Instance:** c6a.2xlarge (8 vCPU, 16 GB RAM, 600 GB disk)

---

## Current State (2026-04-01)

| Resource | Capacity | Requests (66%) | Limits (117%) | Actual Usage |
|----------|----------|----------------|---------------|-------------|
| CPU | 8 vCPU | 5.3 cores | 9.4 cores (overcommitted) | ~2.8 cores (35%) |
| Memory | 15.3 GB | 5.5 GB | 14.7 GB (93%) | 8.4 GB (55%) |
| Disk | 600 GB | — | — | 126 GB (21%) |
| Swap | 0 | — | — | none configured |

### Per-Replication-Job Resource Allocation (Default)

Each sync job spawns 3 containers:

| Container | CPU Request | CPU Limit | Mem Request | Mem Limit |
|-----------|-----------|-----------|-------------|-----------|
| source | 2 cores | 3 cores | 2 GB | 4 GB |
| destination | 1 core | 3 cores | 1 GB | 4 GB |
| orchestrator | 1 core | 3 cores | 1 GB | 4 GB |
| **Per job** | **4 cores** | **9 cores** | **4 GB** | **12 GB** |

Two concurrent jobs = 8 cores request / 18 cores limit / 24 GB memory limit on an 8-core / 16 GB machine.

---

## Improvements

### 1. Reduce Replication Pod Limits

**Impact:** High | **Risk:** Low | **Cost:** Free

Default limits are 3-4x what CDC streams actually use. Reduce to:

| Container | CPU Request | CPU Limit | Mem Request | Mem Limit |
|-----------|-----------|-----------|-------------|-----------|
| source | 500m | 1000m | 512Mi | 1Gi |
| destination | 500m | 1000m | 512Mi | 1Gi |
| orchestrator | 250m | 500m | 256Mi | 512Mi |
| **Per job** | **1.25 cores** | **2.5 cores** | **1.25 GB** | **2.5 GB** |

Two concurrent jobs: 2.5 cores / 5 cores limit / 5 GB memory limit. Well within the 8-core / 16 GB instance.

**How to apply:**

```bash
# Option A: Via abctl (if available)
abctl local install --set "worker.replication.cpu.request=500m" \
  --set "worker.replication.cpu.limit=1000m" \
  --set "worker.replication.memory.request=512Mi" \
  --set "worker.replication.memory.limit=1Gi"

# Option B: Via Helm values override
docker exec airbyte-abctl-control-plane kubectl get configmap -n airbyte-abctl airbyte-abctl-airbyte-env -o yaml
# Edit the resource limits in the configmap or Helm values
```

### 2. Add Swap as Safety Net

**Impact:** Medium | **Risk:** Low | **Cost:** Free

Prevents OOM kills during CDC snapshot memory spikes.

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# Verify
free -h
```

### 3. Set Resource Requests on Airbyte Core Services

**Impact:** Medium | **Risk:** Low | **Cost:** Free

All 8 platform pods (server, worker, temporal, webapp, etc.) run with no resource requests — they can be starved by replication jobs. Set modest baselines:

| Pod | CPU Request | Mem Request |
|-----|-----------|-------------|
| server | 100m | 256Mi |
| worker | 200m | 512Mi |
| temporal | 100m | 256Mi |
| webapp | 50m | 128Mi |
| connector-builder-server | 50m | 128Mi |
| cron | 50m | 128Mi |
| workload-api-server | 100m | 256Mi |
| workload-launcher | 100m | 256Mi |

**Total platform baseline:** 750m CPU, 1.9 GB memory — reserved and protected from replication spikes.

### 4. Disk — No Action Needed

600 GB with 21% used. Lifecycle rules on S3 handle lakehouse data. The `airbyte-cleanup.sh` cron handles Minio + DB pruning monthly.

---

## Expected State After Optimization

| Resource | Capacity | Max 2 Concurrent Jobs | Platform Pods | Headroom |
|----------|----------|----------------------|---------------|----------|
| CPU | 8 cores | 5 cores limit | 0.75 cores | 2.25 cores (28%) |
| Memory | 15.3 GB | 5 GB limit | 1.9 GB | 8.4 GB (55%) |
| Swap | 4 GB | — | — | OOM safety net |

---

## Validation After Applying

1. Run a manual Fishbowl → S3 Lakehouse sync (34 streams)
2. Verify both Fishbowl + Magento Snowflake syncs run concurrently without issues
3. Monitor: `docker stats --no-stream` and `kubectl top pods -n airbyte-abctl`
4. Check no OOM kills: `dmesg -T | grep -i oom`
