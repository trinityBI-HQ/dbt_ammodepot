# Infrastructure Monitoring Patterns

> **Purpose**: Dashboard and alerting patterns for infrastructure metrics with Prometheus + Grafana
> **MCP Validated**: 2026-02-19

## When to Use

- Monitoring server/VM health (CPU, memory, disk, network)
- Kubernetes cluster observability (nodes, pods, workloads)
- Container resource tracking and capacity planning

## Node Exporter Dashboard

Node Exporter exposes Linux system metrics for Prometheus scraping.

### Essential Panels

```promql
# CPU Usage (%)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage (%)
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk I/O (bytes/sec)
rate(node_disk_read_bytes_total[5m])
rate(node_disk_written_bytes_total[5m])

# Network Traffic (bytes/sec)
rate(node_network_receive_bytes_total{device!="lo"}[5m])
rate(node_network_transmit_bytes_total{device!="lo"}[5m])

# System Load (normalized)
node_load1 / count without(cpu, mode) (node_cpu_seconds_total{mode="idle"})

# Disk Space Prediction (time until full)
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 24*3600)
```

### Dashboard Layout

```
Row: Overview (stat panels)
  [CPU %] [Memory %] [Disk %] [Uptime] [Load Avg]
Row: CPU
  [CPU Usage by Mode - stacked area] [CPU by Core - time series]
Row: Memory
  [Memory Usage - time series] [Swap Usage - gauge]
Row: Disk
  [Disk Usage by Mount - table] [Disk I/O - time series]
Row: Network
  [Network Traffic In/Out - time series] [Errors/Drops - time series]
```

## Kubernetes Monitoring

Requires: kube-state-metrics, node-exporter, cadvisor (included in kube-prometheus-stack).

### Cluster Overview

```promql
count(kube_node_info)                                                    # Node count
count by (namespace) (kube_pod_info)                                     # Pods by namespace

# Cluster CPU utilization
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m]))
  / sum(kube_node_status_capacity{resource="cpu"}) * 100

# Cluster memory utilization
sum(container_memory_working_set_bytes{container!=""})
  / sum(kube_node_status_capacity{resource="memory"}) * 100

# Pod restarts (last hour)
sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total[1h])) > 0

kube_pod_status_ready{condition="false"}                                 # Pods not ready
kube_deployment_status_replicas_unavailable > 0                          # Unavailable replicas
```

### Namespace Resources

```promql
# CPU request vs actual by namespace
sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})

# Top pods by CPU
topk(10, sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))
```

## Container Monitoring

```promql
# CPU throttling (%)
rate(container_cpu_cfs_throttled_seconds_total[5m])
  / rate(container_cpu_cfs_periods_total[5m]) * 100

# Memory vs limit (%)
container_memory_working_set_bytes{container!=""}
  / container_spec_memory_limit_bytes{container!=""} * 100

# OOMKilled containers
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}
```

## Infrastructure Alert Rules

```yaml
groups:
  - name: infrastructure
    interval: 1m
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "High CPU on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "Disk below 15% on {{ $labels.instance }}"

      - alert: HighMemory
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
        for: 10m
        labels: { severity: warning }

      - alert: PodCrashLooping
        expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "{{ $labels.namespace }}/{{ $labels.pod }} restarting frequently"

      - alert: NodeNotReady
        expr: kube_node_status_condition{condition="Ready", status="true"} == 0
        for: 5m
        labels: { severity: critical }
```

## Best Practices

- **Use recording rules** for expensive queries (pre-compute as new metrics)
- **Set `$__rate_interval`** in rate queries instead of hardcoded intervals
- **Use variables** for instance, namespace, and cluster filtering
- **Include prediction panels** for disk space and capacity planning
- **Alert on trends**, not just thresholds (e.g., disk filling rate)

## Related

- [Application Monitoring](application-monitoring.md) - RED/USE method dashboards
- [Data Sources](../concepts/data-sources.md) - Prometheus configuration
- [Alerting](../concepts/alerting.md) - Alert rule configuration
- [Kubernetes KB](../../../containerization/kubernetes/) - Kubernetes patterns
