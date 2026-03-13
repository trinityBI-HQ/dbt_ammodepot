# Prometheus Knowledge Base

> **Purpose**: Open-source systems monitoring and alerting toolkit with multi-dimensional data model and PromQL
> **MCP Validated**: 2026-02-20

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/architecture.md](concepts/architecture.md) | Pull-based model, TSDB, server components, exporters |
| [concepts/data-model.md](concepts/data-model.md) | Metric types (counter, gauge, histogram, summary), labels, time series |
| [concepts/promql.md](concepts/promql.md) | PromQL fundamentals, selectors, functions, operators |
| [concepts/service-discovery.md](concepts/service-discovery.md) | Static configs, Kubernetes SD, Consul, file-based, EC2/GCE |
| [concepts/alerting.md](concepts/alerting.md) | Alertmanager, alert rules, routing, silencing, inhibition |
| [concepts/storage.md](concepts/storage.md) | Local TSDB, remote write/read, retention, compaction |
| [patterns/kubernetes-monitoring.md](patterns/kubernetes-monitoring.md) | ServiceMonitor, PodMonitor, kube-prometheus-stack |
| [patterns/alerting-patterns.md](patterns/alerting-patterns.md) | Alert design, runbook links, severity levels, escalation |
| [patterns/recording-rules.md](patterns/recording-rules.md) | Pre-computed queries, naming conventions, aggregation |
| [patterns/federation-scaling.md](patterns/federation-scaling.md) | Hierarchical federation, Thanos, Mimir, VictoriaMetrics |
| [quick-reference.md](quick-reference.md) | PromQL cheat sheet, metric types, config snippets |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Pull Model** | Prometheus scrapes metrics from HTTP endpoints at configured intervals |
| **Time Series** | Streams of timestamped values identified by metric name + label set |
| **Labels** | Key-value pairs for multi-dimensional filtering/aggregation |
| **PromQL** | Functional query language for selecting, aggregating, and transforming time series |
| **Alertmanager** | Handles alert deduplication, grouping, routing, silencing, and inhibition |
| **Exporters** | Bridge apps that expose third-party metrics in Prometheus format |
| **Recording Rules** | Pre-compute expensive queries and store results as new time series |
| **Service Discovery** | Dynamic target discovery via Kubernetes, Consul, DNS, EC2, file-based configs |

## Installation

```bash
# Docker
docker run -d -p 9090:9090 --name prometheus \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:v3.9.1

# Helm (Kubernetes - kube-prometheus-stack)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

Default UI at `http://localhost:9090`. No authentication by default.

## Getting Started

1. **Configure targets**: Edit `prometheus.yml` with `scrape_configs`
2. **Start Prometheus**: Run binary or container with config
3. **Explore metrics**: Use the expression browser with PromQL
4. **Add exporters**: Deploy node_exporter, blackbox_exporter, etc.
5. **Set up alerting**: Define alert rules, configure Alertmanager
6. **Connect Grafana**: Add Prometheus as data source

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/architecture.md, concepts/data-model.md |
| **Intermediate** | concepts/promql.md, concepts/alerting.md, patterns/alerting-patterns.md |
| **Advanced** | concepts/storage.md, patterns/federation-scaling.md, patterns/recording-rules.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ci-cd-specialist | patterns/kubernetes-monitoring.md | Monitor CI/CD pipelines |
| infra-deployer | patterns/kubernetes-monitoring.md | Deploy monitoring stack |
| kb-architect | All files | Generate monitoring documentation |

## Cross-References

| Related KB | Relevance |
|------------|-----------|
| [Grafana](../grafana/) | Visualization layer for Prometheus metrics |
| [Kubernetes](../../containerization/kubernetes/) | Primary monitoring target, kube-prometheus-stack |
| [Terraform](../../iac/terraform/) | IaC deployment for Prometheus infrastructure |
| [Docker Compose](../../containerization/docker-compose/) | Local Prometheus + Grafana development stack |

## Project Context

CNCF graduated project. Pull-based architecture scrapes instrumented HTTP endpoints. Native Kubernetes integration via kube-prometheus-stack and ServiceMonitor CRDs. Scales with federation, remote write, and long-term storage (Thanos, Mimir, VictoriaMetrics). Prometheus 3.x adds native histograms, OTLP ingestion, and refreshed UI.
