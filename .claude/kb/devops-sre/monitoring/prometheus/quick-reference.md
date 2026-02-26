# Prometheus Quick Reference

> Fast lookup tables. For detailed examples, see linked files.
> **MCP Validated**: 2026-02-20

## Metric Types

| Type | Description | PromQL Functions | Example |
|------|-------------|------------------|---------|
| Counter | Monotonically increasing | `rate()`, `increase()`, `resets()` | `http_requests_total` |
| Gauge | Can go up or down | `avg_over_time()`, `delta()` | `temperature_celsius` |
| Histogram | Observations in buckets | `histogram_quantile()`, `rate(..bucket)` | `request_duration_seconds` |
| Summary | Client-side quantiles | Direct read (pre-calculated) | `go_gc_duration_seconds` |

## Essential PromQL

```promql
rate(http_requests_total[5m])                                               # Request rate (per-sec)
increase(http_requests_total[1h])                                           # Total increase over 1h
sum by (service) (rate(http_requests_total[5m]))                            # Rate grouped by service
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))     # p95 latency
topk(5, sum by (job) (rate(http_requests_total[5m])))                       # Top 5 jobs by rate
count by (status) (http_requests_total)                                     # Count series by status
absent(up{job="myapp"})                                                     # Detect missing target
changes(process_start_time_seconds[1h])                                     # Process restarts
predict_linear(node_filesystem_avail_bytes[6h], 24*3600)                    # Disk full prediction
```

## Label Matchers

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` | Exact match | `job="api"` |
| `!=` | Not equal | `status!="200"` |
| `=~` | Regex match | `method=~"GET\|POST"` |
| `!~` | Negative regex | `path!~"/health.*"` |

## Aggregation Operators

| Operator | Purpose | Example |
|----------|---------|---------|
| `sum` | Total | `sum by (job) (rate(requests[5m]))` |
| `avg` | Average | `avg by (instance) (cpu_usage)` |
| `min` / `max` | Extremes | `max by (cluster) (memory_bytes)` |
| `count` | Count series | `count by (job) (up)` |
| `stddev` | Standard deviation | `stddev by (service) (latency)` |
| `quantile` | Aggregated quantile | `quantile(0.95, latency) by (service)` |
| `topk` / `bottomk` | Top/bottom N | `topk(10, rate(errors[5m]))` |

## Minimal Config (`prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - "rules/*.yml"
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
```

## Common Exporters

| Exporter | Port | Metrics |
|----------|------|---------|
| node_exporter | 9100 | CPU, memory, disk, network |
| blackbox_exporter | 9115 | HTTP, TCP, DNS, ICMP probes |
| mysqld_exporter | 9104 | MySQL server metrics |
| postgres_exporter | 9187 | PostgreSQL metrics |
| redis_exporter | 9121 | Redis server metrics |
| cadvisor | 8080 | Container resource usage |
| kube-state-metrics | 8080 | Kubernetes object state |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use `rate()` on gauges | Use `rate()` only on counters/histograms |
| Use short range vectors | Use `[5m]` minimum (2x scrape interval) |
| Forget `by` in aggregations | Always specify grouping labels |
| Create high-cardinality labels | Avoid user IDs, request IDs as labels |
| Alert on raw counters | Alert on `rate()` or `increase()` |
| Skip `for` in alert rules | Require sustained firing to reduce flapping |
| Ignore `absent()` | Use it to detect missing targets |

## Related

- Concepts: `concepts/architecture.md`, `concepts/data-model.md`, `concepts/promql.md`, `concepts/alerting.md`
- Full index: `index.md`
