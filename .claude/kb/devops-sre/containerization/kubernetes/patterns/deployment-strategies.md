# Deployment Strategies

> **Purpose**: Rolling updates, blue-green, and canary deployment patterns for Kubernetes
> **MCP Validated**: 2026-02-19

## When to Use

- Zero-downtime deployments for production workloads
- Gradual rollouts to minimize blast radius
- A/B testing or feature validation with subset of traffic
- Rollback capability for failed releases

## Rolling Update (Built-in)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Max pods over desired count during update
      maxUnavailable: 0      # Zero downtime — always keep all replicas running
  template:
    spec:
      containers:
      - name: app
        image: my-app:2.0.0
        readinessProbe:       # Critical for safe rolling updates
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

**Rollout commands:**

```bash
kubectl rollout status deploy/web-app          # Watch progress
kubectl rollout history deploy/web-app         # View history
kubectl rollout undo deploy/web-app            # Rollback to previous
kubectl rollout undo deploy/web-app --to-revision=2  # Specific revision
kubectl rollout pause deploy/web-app           # Pause mid-rollout
kubectl rollout resume deploy/web-app          # Resume paused rollout
```

## Blue-Green Deployment

```yaml
# Two Deployments: blue (current) and green (new)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
      version: blue
  template:
    metadata:
      labels:
        app: web-app
        version: blue
    spec:
      containers:
      - name: app
        image: my-app:1.0.0
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
      version: green
  template:
    metadata:
      labels:
        app: web-app
        version: green
    spec:
      containers:
      - name: app
        image: my-app:2.0.0
---
# Service — switch selector to promote green
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
    version: blue     # Change to "green" to switch traffic
  ports:
  - port: 80
    targetPort: 8080
```

**Switch traffic**: `kubectl patch svc web-app -p '{"spec":{"selector":{"version":"green"}}}'`

**Rollback**: Switch selector back to `blue`.

## Canary Deployment (with Argo Rollouts)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: web-app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 10          # 10% traffic to canary
      - pause: {duration: 5m}  # Observe for 5 minutes
      - setWeight: 30
      - pause: {duration: 5m}
      - setWeight: 60
      - pause: {duration: 5m}
      - setWeight: 100         # Full promotion
      canaryService: web-app-canary
      stableService: web-app-stable
  template:
    spec:
      containers:
      - name: app
        image: my-app:2.0.0
```

## Configuration

| Strategy | Downtime | Resource Overhead | Rollback Speed | Complexity |
|----------|----------|-------------------|----------------|------------|
| Rolling Update | None | Low (+1 pod) | Medium (undo) | Low |
| Blue-Green | None | High (2x replicas) | Instant (switch) | Medium |
| Canary | None | Low (+10-30%) | Instant (abort) | High |

## See Also

- [Workloads](../concepts/workloads.md) — Deployment spec details
- [Scaling & Autoscaling](scaling-autoscaling.md)
- [Production Best Practices](production-best-practices.md)
