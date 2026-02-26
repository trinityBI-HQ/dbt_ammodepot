# Prometheus Service Discovery

> **Purpose**: Dynamic target discovery -- Kubernetes, Consul, file-based, EC2/GCE, and static configs
> **MCP Validated**: 2026-02-20

## Overview

Service discovery (SD) allows Prometheus to automatically find and scrape targets as infrastructure changes. Targets are discovered, relabeled, and added to scrape pools dynamically.

## Discovery Flow

```
SD Plugin -> Discovered Targets -> relabel_configs -> Active Targets -> Scrape
                                     (filter/transform)
```

Labels prefixed with `__` are internal and dropped after relabeling unless mapped to a visible label.

## Static Configuration

Simplest approach -- define targets directly in `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: "myapp"
    scrape_interval: 15s
    static_configs:
      - targets: ["app1:8080", "app2:8080"]
        labels:
          env: production
          team: platform
```

Best for: fixed infrastructure, development environments.

## Kubernetes Service Discovery

The most common SD mechanism in cloud-native environments.

### Roles

| Role | Discovers | Use Case |
|------|-----------|----------|
| `node` | Kubelet addresses | Node-level metrics |
| `pod` | Pod IPs and ports | Application metrics |
| `service` | Service cluster IPs | Service-level endpoints |
| `endpoints` | Endpoints behind services | Most common for app monitoring |
| `endpointslice` | EndpointSlice resources | Scalable alternative to endpoints |
| `ingress` | Ingress resources | Blackbox probing of ingresses |

### Common Pattern

Use pod annotations (`prometheus.io/scrape: "true"`, `prometheus.io/port`, `prometheus.io/path`) with relabel configs to filter and route scrape targets. See [Kubernetes Monitoring](../patterns/kubernetes-monitoring.md) for full examples.

## File-Based Service Discovery

Prometheus watches JSON or YAML files for target changes. Ideal for custom integrations or configuration management tools.

```yaml
scrape_configs:
  - job_name: "file-sd"
    file_sd_configs:
      - files:
          - "/etc/prometheus/targets/*.json"
        refresh_interval: 5m
```

Target file (`/etc/prometheus/targets/apps.json`):

```json
[
  {
    "targets": ["app1:8080", "app2:8080"],
    "labels": { "env": "production", "service": "api" }
  }
]
```

## Consul Service Discovery

```yaml
scrape_configs:
  - job_name: "consul"
    consul_sd_configs:
      - server: "consul.example.com:8500"
        services: ["web", "api"]
        tags: ["production"]
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: service
```

## Cloud and DNS Service Discovery

| Type | Key Config | Use Case |
|------|-----------|----------|
| `ec2_sd_configs` | `region`, `port`, `filters` (by tag) | AWS EC2 instances |
| `gce_sd_configs` | `project`, `zone`, `filter` | GCP Compute Engine |
| `dns_sd_configs` | `names` (SRV/A records), `type` | DNS-based discovery |
| `azure_sd_configs` | `subscription_id`, `resource_group` | Azure VMs |

All cloud SD types support `relabel_configs` to map `__meta_*` labels to visible labels.

## Relabeling

Relabeling transforms labels before scraping (`relabel_configs`) or before storage (`metric_relabel_configs`).

| Action | Purpose |
|--------|---------|
| `keep` | Only keep targets matching regex |
| `drop` | Drop targets matching regex |
| `replace` | Replace label value using regex capture groups |
| `labelmap` | Copy labels matching regex pattern |
| `labeldrop` | Remove labels matching regex |
| `hashmod` | Hash-based sharding for horizontal scaling |

```yaml
relabel_configs:
  # Drop targets in kube-system namespace
  - source_labels: [__meta_kubernetes_namespace]
    action: drop
    regex: kube-system
  # Map all __meta_kubernetes_pod_label_* to pod labels
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
```

## Related

- [Architecture](architecture.md) - How discovery fits into the scrape pipeline
- [Kubernetes Monitoring](../patterns/kubernetes-monitoring.md) - ServiceMonitor/PodMonitor patterns
- [Federation & Scaling](../patterns/federation-scaling.md) - Multi-cluster discovery
