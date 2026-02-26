# Kubernetes Monitoring Patterns

> **Purpose**: kube-prometheus-stack, ServiceMonitor, PodMonitor, and Kubernetes-native Prometheus deployment
> **MCP Validated**: 2026-02-20

## When to Use

- Monitoring Kubernetes clusters (nodes, pods, workloads, control plane)
- Deploying a full monitoring stack (Prometheus + Grafana + Alertmanager) on Kubernetes
- Using Prometheus Operator CRDs for declarative scrape configuration

## kube-prometheus-stack

The standard Helm chart that deploys Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, and kube-state-metrics.

### Installation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### Key Components Deployed

| Component | Purpose |
|-----------|---------|
| **Prometheus Operator** | Manages Prometheus/Alertmanager instances via CRDs |
| **Prometheus** | Metrics collection and storage |
| **Alertmanager** | Alert routing and notification |
| **Grafana** | Dashboards (pre-configured with Prometheus datasource) |
| **node-exporter** | Host-level metrics (DaemonSet) |
| **kube-state-metrics** | Kubernetes object state metrics |

### Included Dashboards

Pre-built Grafana dashboards for cluster overview, node metrics, pod resources, namespace usage, persistent volumes, and control plane health.

## ServiceMonitor

The primary CRD for declaring what Kubernetes Services to scrape. The Operator translates ServiceMonitors into Prometheus scrape configuration.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-monitor
  namespace: monitoring
  labels:
    release: kube-prom              # Must match Operator's serviceMonitorSelector
spec:
  namespaceSelector:
    matchNames: ["production"]
  selector:
    matchLabels:
      app: api-server
  endpoints:
    - port: metrics                 # Named port from the Service
      interval: 15s
      path: /metrics
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: "go_.*"
          action: drop              # Drop verbose Go runtime metrics
```

### When to Use ServiceMonitor

- Application exposes metrics via a Kubernetes Service
- Standard web services, APIs, and microservices
- Most common choice for application monitoring

## PodMonitor

Scrapes pods directly without requiring a Kubernetes Service. Useful for workloads that do not need service networking.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: batch-jobs
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: ["data-pipelines"]
  selector:
    matchLabels:
      app: etl-worker
  podMetricsEndpoints:
    - port: metrics
      interval: 30s
```

### When to Use PodMonitor

- CronJobs, batch jobs, DaemonSets without a Service
- Pods that expose metrics but do not handle inbound traffic
- Sidecar containers with their own metrics port

## ServiceMonitor vs PodMonitor

| Aspect | ServiceMonitor | PodMonitor |
|--------|---------------|------------|
| Discovery | Via Kubernetes Service | Direct pod selection |
| Use case | Services handling traffic | Jobs, workers, sidecars |
| Requirement | Service + named port | Pod labels + port |
| Prevalence | Most common | Specialized workloads |

## ScrapeConfig (Advanced)

For targets outside Kubernetes or custom SD mechanisms:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: external-targets
spec:
  staticConfigs:
    - targets: ["external-db.example.com:9187"]
      labels:
        env: production
```

## Custom Values (Key Production Overrides)

| Setting | Example | Purpose |
|---------|---------|---------|
| `prometheusSpec.retention` | `30d` | Time-based retention |
| `prometheusSpec.retentionSize` | `100GB` | Size-based retention |
| `prometheusSpec.resources.requests` | `cpu: "2", memory: "8Gi"` | Resource reservation |
| `prometheusSpec.storageSpec...storage` | `200Gi` | PVC size |
| `prometheusSpec.serviceMonitorSelector` | `{}` | Discover all ServiceMonitors |
| `prometheusSpec.podMonitorSelector` | `{}` | Discover all PodMonitors |
| `prometheusSpec.remoteWrite[0].url` | Thanos/Mimir URL | Long-term storage |

## Monitoring Application Metrics

1. Instrument your app with a client library (`prometheus_client` for Python, `prom-client` for Node.js)
2. Expose a `/metrics` endpoint
3. Create a Kubernetes Service with a **named port** (e.g., `metrics`)
4. Deploy a ServiceMonitor selecting that Service by label

## PrometheusRule CRD

Define alerting and recording rules as Kubernetes resources:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  labels:
    release: kube-prom
spec:
  groups:
    - name: app.rules
      rules:
        - alert: HighErrorRate
          expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) > 0.1
          for: 5m
          labels: { severity: critical }
          annotations:
            summary: "High error rate on {{ $labels.service }}"
```

## Best Practices

- Set `serviceMonitorSelector: {}` and `podMonitorSelector: {}` to discover across all namespaces
- Use `metricRelabelings` to drop high-cardinality or unnecessary metrics at scrape time
- Deploy node-exporter as DaemonSet (included in kube-prometheus-stack)
- Use `PrometheusRule` CRDs for GitOps-managed alert rules
- Set resource requests/limits on Prometheus pods based on series count
- Use persistent volumes for Prometheus data to survive pod restarts

## Related

- [Architecture](../concepts/architecture.md) - Prometheus components
- [Service Discovery](../concepts/service-discovery.md) - Kubernetes SD internals
- [Federation & Scaling](federation-scaling.md) - Multi-cluster monitoring
- [Kubernetes KB](../../../containerization/kubernetes/) - Kubernetes concepts
