# Kubernetes Workloads

> **Purpose**: Pod types and controllers — Deployments, StatefulSets, DaemonSets, Jobs, CronJobs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Workload resources manage Pods declaratively. Deployments handle stateless apps, StatefulSets manage stateful apps with stable identity, DaemonSets run per-node agents, and Jobs/CronJobs handle batch tasks.

## Deployment (Stateless Apps)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: my-app:1.2.0
        ports:
        - containerPort: 8080
        resources:
          requests: { cpu: 100m, memory: 128Mi }
          limits: { cpu: 500m, memory: 512Mi }
```

## StatefulSet (Stateful Apps)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres  # Required headless Service
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:   # PVC per Pod (postgres-data-0, -1, -2)
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

**Guarantees**: Stable pod names (`postgres-0`, `-1`, `-2`), ordered creation/deletion, stable DNS, persistent storage per pod.

## DaemonSet (Per-Node Agents)

Runs exactly one Pod per node. Use for: log collectors, monitoring agents, network plugins. Define like a Deployment but with `kind: DaemonSet` and no `replicas` field.

## Job and CronJob

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
      - name: migrate
        image: my-app:1.2.0
        command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-backup
spec:
  schedule: "0 2 * * *"          # 2 AM daily
  concurrencyPolicy: Forbid       # Skip if previous still running
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool:latest
          restartPolicy: OnFailure
```

## In-Place Pod Resizing (v1.35 GA)

Resize CPU/memory on running pods without restart using `resizePolicy`:

```yaml
    resizePolicy:
    - resourceName: cpu
      restartPolicy: NotRequired    # CPU resizes without restart
    - resourceName: memory
      restartPolicy: RestartContainer  # Memory may require restart
```

Apply via `kubectl patch pod <name> --subresource resize`. See [Scaling & Autoscaling](../patterns/scaling-autoscaling.md) for patterns.

## Dynamic Resource Allocation (DRA) (v1.34+)

Request specialized hardware (GPUs, FPGAs) via `ResourceClaim` objects with `deviceClassName`. DRA replaces the legacy device-plugin model with richer scheduling semantics for AI/ML workloads.

## Quick Reference

| Resource | Use Case | Key Feature |
|----------|----------|-------------|
| Deployment | Stateless apps | Rolling updates, scaling |
| StatefulSet | Databases, queues | Stable identity, ordered ops |
| DaemonSet | Node agents | One pod per node |
| Job | Batch tasks | Run to completion |
| CronJob | Scheduled tasks | Cron-based scheduling |

## Related

- [Configuration](configuration.md) — ConfigMaps and Secrets for workloads
- [Storage](storage.md) — PersistentVolumes for StatefulSets
- [Deployment Strategies](../patterns/deployment-strategies.md)
