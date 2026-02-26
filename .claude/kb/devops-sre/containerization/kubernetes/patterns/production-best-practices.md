# Production Best Practices

> **Purpose**: Resource management, health probes, PDBs, affinity, taints, and operational patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Deploying workloads to production Kubernetes clusters
- Improving reliability and availability of services
- Implementing resource governance and scheduling constraints
- Planning for maintenance and disruption scenarios

## Resource Requests and Limits

```yaml
spec:
  containers:
  - name: app
    resources:
      requests:           # Scheduling guarantee
        cpu: 100m         # 0.1 CPU cores
        memory: 256Mi     # Minimum memory
      limits:             # Hard ceiling
        cpu: 500m         # Throttled beyond this
        memory: 512Mi     # OOMKilled beyond this
```

**Guidelines:**
- Always set `requests` (used for scheduling and HPA)
- Set memory `limits` to prevent OOM (typically 1.5-2x requests)
- CPU `limits` cause throttling; some teams omit them and only set requests
- Use VPA in `Off` mode to get recommendations before setting values

## Health Probes

```yaml
spec:
  containers:
  - name: app
    startupProbe:           # Slow-starting apps (checked first)
      httpGet:
        path: /healthz
        port: 8080
      failureThreshold: 30
      periodSeconds: 10     # Up to 5 min to start (30 * 10s)
    readinessProbe:         # Ready to receive traffic?
      httpGet:
        path: /ready
        port: 8080
      periodSeconds: 10
      failureThreshold: 3
    livenessProbe:          # Still alive? (restarts on failure)
      httpGet:
        path: /healthz
        port: 8080
      periodSeconds: 15
      failureThreshold: 3
```

| Probe | Purpose | On Failure |
|-------|---------|------------|
| **Startup** | Wait for slow initialization | Block liveness/readiness checks |
| **Readiness** | Can this pod handle traffic? | Remove from Service endpoints |
| **Liveness** | Is this pod stuck/deadlocked? | Restart container |

## PodDisruptionBudget (PDB)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2            # OR use maxUnavailable: 1
  selector:
    matchLabels:
      app: web-app
```

Protects against voluntary disruptions (node drains, cluster upgrades). Does not protect against involuntary disruptions (hardware failures).

## Affinity and Anti-Affinity

```yaml
spec:
  affinity:
    # Spread pods across nodes
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: ["web-app"]
        topologyKey: kubernetes.io/hostname
    # Prefer specific node types
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: node-type
            operator: In
            values: ["compute-optimized"]
```

## Topology Spread Constraints

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: web-app
```

Spread pods evenly across zones for high availability.

## Taints and Tolerations

```yaml
# Taint a node (kubectl)
# kubectl taint nodes gpu-node dedicated=gpu:NoSchedule

# Pod tolerating the taint
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

| Effect | Behavior |
|--------|----------|
| `NoSchedule` | Don't schedule new pods without toleration |
| `PreferNoSchedule` | Try to avoid, but allow if necessary |
| `NoExecute` | Evict existing pods without toleration |

## Labels and Annotations

```yaml
metadata:
  labels:                          # For selection and grouping
    app.kubernetes.io/name: web-app
    app.kubernetes.io/version: "2.0.0"
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: my-platform
    app.kubernetes.io/managed-by: helm
  annotations:                     # For metadata/tooling
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
```

## Production Checklist

| Category | Check |
|----------|-------|
| Resources | Requests and limits on all containers |
| Probes | Liveness, readiness, and startup probes configured |
| Availability | PDB set, anti-affinity across nodes/zones |
| Security | Non-root, read-only FS, drop ALL capabilities |
| Images | Pinned tags, vulnerability scanned, signed |
| Config | Secrets in external manager, ConfigMaps for config |
| Networking | NetworkPolicies restricting traffic |
| Observability | Metrics exported, structured logging, distributed tracing |
| Scaling | HPA configured, Cluster Autoscaler enabled |
| Backups | etcd backups, PV snapshots |

## See Also

- [Security](../concepts/security.md) — RBAC, Pod Security Standards
- [Scaling & Autoscaling](scaling-autoscaling.md) — HPA, VPA, KEDA
- [Deployment Strategies](deployment-strategies.md) — Safe rollout patterns
