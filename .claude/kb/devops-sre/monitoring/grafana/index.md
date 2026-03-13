# Grafana Knowledge Base

> **Purpose**: Open-source analytics and interactive visualization platform for metrics, logs, and traces
> **MCP Validated**: 2026-02-19

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/dashboards-panels.md](concepts/dashboards-panels.md) | Dashboard structure, panel types, variables, transformations |
| [concepts/data-sources.md](concepts/data-sources.md) | Data source configuration, Prometheus, Loki, SQL, provisioning |
| [concepts/alerting.md](concepts/alerting.md) | Unified alerting, alert rules, contact points, notification policies |
| [concepts/provisioning.md](concepts/provisioning.md) | Dashboards-as-code, Terraform provider, Grafonnet, API automation |
| [patterns/infrastructure-monitoring.md](patterns/infrastructure-monitoring.md) | Node Exporter, Kubernetes, container and network monitoring |
| [patterns/application-monitoring.md](patterns/application-monitoring.md) | RED/USE methods, SLO/SLI dashboards, API and database monitoring |
| [patterns/dashboard-as-code.md](patterns/dashboard-as-code.md) | Terraform provisioning, Grafonnet, CI/CD pipelines, multi-env |
| [patterns/log-monitoring.md](patterns/log-monitoring.md) | Loki + Grafana, LogQL patterns, log-metric correlation, alerting |
| [quick-reference.md](quick-reference.md) | Panel types, data sources, PromQL, variable syntax, shortcuts |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Dashboards** | Configurable views with rows, panels, variables, and time controls |
| **Panels** | Individual visualizations (time series, stat, gauge, table, heatmap) |
| **Data Sources** | Connectors to Prometheus, Loki, PostgreSQL, InfluxDB, and 150+ others |
| **Alerting** | Unified alerting with multi-dimensional rules, contact points, routing |
| **Variables** | Template variables for dynamic, reusable dashboards (`$var`, `${var}`) |
| **Provisioning** | File-based and API-driven configuration for dashboards-as-code |
| **Plugins** | Extensible panels, data sources, and apps from the Grafana ecosystem |

## Installation

```bash
# Docker
docker run -d -p 3000:3000 --name grafana grafana/grafana-oss:11.5.0

# Helm (Kubernetes)
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana --namespace monitoring
```

Default credentials: `admin` / `admin` (change on first login).

## Getting Started

1. **Add data source**: Configuration > Data Sources > Add (Prometheus, Loki, etc.)
2. **Create dashboard**: Dashboards > New Dashboard > Add Visualization
3. **Write query**: Select data source, write PromQL/LogQL, configure panel
4. **Set up alerting**: Alerting > Alert Rules > New Alert Rule
5. **Share**: Export JSON for version control or use dashboard links

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/dashboards-panels.md, concepts/data-sources.md |
| **Intermediate** | concepts/alerting.md, patterns/application-monitoring.md |
| **Advanced** | concepts/provisioning.md, patterns/dashboard-as-code.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ci-cd-specialist | patterns/dashboard-as-code.md | Provision dashboards in CI/CD |
| infra-deployer | patterns/infrastructure-monitoring.md | Monitor deployed infrastructure |
| kb-architect | All files | Generate monitoring documentation |

## Cross-References

| Related KB | Relevance |
|------------|-----------|
| [Prometheus](../prometheus/) | Primary metrics data source |
| [Kubernetes](../../containerization/kubernetes/) | Cluster monitoring with Prometheus + Grafana |
| [Terraform](../../iac/terraform/) | Grafana Terraform provider for provisioning |
| [Elementary](../../../data-engineering/observability/elementary/) | Data observability dashboards |

## Project Context

Connects to 150+ data sources. Unified alerting with flexible notification routing. Dashboard-as-code via file provisioning, Terraform, and Grafonnet. Part of the LGTM stack (Loki, Grafana, Tempo, Mimir). Grafana Cloud offers managed hosting with free tier.
