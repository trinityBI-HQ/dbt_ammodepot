# Scaling & Autoscaling

> **Purpose**: HPA, VPA, Cluster Autoscaler, and KEDA for automatic scaling
> **MCP Validated**: 2026-02-19

## When to Use

- Variable traffic patterns requiring dynamic scaling
- Cost optimization by scaling down during off-peak
- Resource-intensive workloads needing right-sized containers
- Event-driven workloads scaling to zero

## Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60               # Scale down max 10% per minute
    scaleUp:
      stabilizationWindowSeconds: 0      # Scale up immediately
      policies:
      - type: Pods
        value: 4
        periodSeconds: 60               # Add max 4 pods per minute
```

**Prerequisites**: Metrics Server must be installed. Pods must have resource `requests` set.

## Vertical Pod Autoscaler (VPA)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  updatePolicy:
    updateMode: "Auto"     # "Off" for recommendations only
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
```

| Update Mode | Behavior |
|-------------|----------|
| `Off` | Recommendations only (safe to start) |
| `Initial` | Set resources on pod creation only |
| `Auto` | Evict and recreate pods with new resources |

**Note**: VPA and HPA should not target the same metric (CPU/memory). Use HPA for scaling replicas and VPA for right-sizing individual pods.

## Cluster Autoscaler

Automatically adjusts node pool size based on pending pods:

```yaml
# GKE: Enable on node pool
# EKS: Deploy Cluster Autoscaler or use Karpenter
# AKS: Enable on node pool

# Key flags:
# --scale-down-delay-after-add=10m
# --scale-down-unneeded-time=10m
# --max-node-provision-time=15m
```

| Setting | Description | Recommended |
|---------|-------------|-------------|
| `scale-down-delay-after-add` | Wait after adding node before removing | 10m |
| `scale-down-unneeded-time` | How long node must be unneeded | 10m |
| `max-graceful-termination-sec` | Grace period for pod eviction | 600 |

## KEDA (Event-Driven Autoscaling)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: queue-processor
spec:
  scaleTargetRef:
    name: queue-worker
  minReplicaCount: 0              # Scale to zero when idle
  maxReplicaCount: 50
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka:9092
      consumerGroup: my-group
      topic: events
      lagThreshold: "100"         # Scale when lag > 100
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      query: rate(http_requests_total[2m])
      threshold: "50"
```

KEDA supports 60+ scalers: Kafka, SQS, RabbitMQ, Prometheus, Cron, PostgreSQL, Redis, and more.

## Configuration

| Scaler | Best For | Scale to Zero |
|--------|----------|---------------|
| HPA | CPU/memory-based steady traffic | No (min 1) |
| VPA | Right-sizing resource requests | No |
| Cluster Autoscaler | Node-level scaling | Nodes only |
| KEDA | Event-driven, queue-based | Yes |

## In-Place Pod Resizing (v1.35 GA)

Resize running pods without restart, complementing VPA and HPA:

```yaml
# Patch a running pod's resources in-place
# kubectl patch pod my-pod --subresource resize --patch \
#   '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"200m"},"limits":{"cpu":"1"}}}]}}'
```

| Scaling Method | What Changes | Restart Required | Use Case |
|----------------|-------------|------------------|----------|
| HPA | Number of pods | No | Traffic-based scaling |
| VPA (Auto) | Pod resources | Yes (recreate) | Right-sizing |
| In-Place Resize | Pod resources | No (when possible) | Live resource adjustment |

**Best practice**: Combine In-Place Resizing with VPA recommendations. Use VPA in `Off` mode for recommendations, then apply changes via In-Place Resize to avoid pod restarts for CPU changes.

## See Also

- [Workloads](../concepts/workloads.md) — Deployment replicas, In-Place Resizing, DRA
- [Production Best Practices](production-best-practices.md) — Resource requests/limits
- [Deployment Strategies](deployment-strategies.md)
