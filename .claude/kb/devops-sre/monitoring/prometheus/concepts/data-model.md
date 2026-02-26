# Prometheus Data Model

> **Purpose**: Metric types, labels, time series structure, and naming conventions
> **MCP Validated**: 2026-02-20

## Overview

Every time series in Prometheus is uniquely identified by its **metric name** and a set of **labels** (key-value pairs). Each sample consists of a float64 value and a millisecond-precision timestamp.

```
<metric_name>{<label_name>=<label_value>, ...}  <value> <timestamp>
```

Example:
```
http_requests_total{method="GET", handler="/api", status="200"} 1027 1708348800000
```

## Metric Types

### Counter

A cumulative value that only increases (or resets to zero on restart).

```python
# Python client
from prometheus_client import Counter
requests = Counter('http_requests_total', 'Total HTTP requests', ['method', 'status'])
requests.labels(method='GET', status='200').inc()
```

**PromQL usage**: Always wrap in `rate()` or `increase()` -- never alert on raw counter values.

```promql
rate(http_requests_total[5m])        # Per-second rate
increase(http_requests_total[1h])    # Total increase over window
```

### Gauge

A value that can go up or down (current state).

```python
from prometheus_client import Gauge
temperature = Gauge('room_temperature_celsius', 'Current temperature')
temperature.set(22.5)
```

**PromQL usage**: Query directly, or use over-time functions.

```promql
node_memory_MemAvailable_bytes                    # Current value
avg_over_time(cpu_usage_percent[1h])              # Average over 1h
delta(temperature_celsius[30m])                   # Change over 30m
predict_linear(disk_free_bytes[6h], 24*3600)      # Prediction
```

### Histogram

Counts observations in configurable buckets, exposing `_bucket`, `_sum`, and `_count` series.

```python
from prometheus_client import Histogram
latency = Histogram('http_request_duration_seconds', 'Request latency',
                    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10])
latency.observe(0.042)
```

**Exposed series**:
```
http_request_duration_seconds_bucket{le="0.05"}   # Count <= 0.05s
http_request_duration_seconds_bucket{le="+Inf"}   # Total count
http_request_duration_seconds_sum                  # Sum of observed values
http_request_duration_seconds_count                # Total observations
```

**PromQL usage**:
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))   # p95
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))   # Median
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])  # Avg
```

### Summary

Pre-calculates quantiles on the client side. Cannot be aggregated across instances.

```
rpc_duration_seconds{quantile="0.5"}   0.042
rpc_duration_seconds{quantile="0.99"}  0.87
rpc_duration_seconds_sum               1234.5
rpc_duration_seconds_count             5000
```

**Prefer histograms** over summaries: histograms are aggregatable, support `histogram_quantile()`, and bucket boundaries can be adjusted after deployment.

### Native Histograms (Prometheus 3.x)

Stable since Prometheus 3.8. Exponential bucket boundaries are automatic, requiring no manual bucket configuration. Enable via:

```yaml
scrape_configs:
  - job_name: myapp
    scrape_native_histograms: true
```

## Labels

Labels provide the multi-dimensional data model. Every unique combination of labels creates a distinct time series.

### Best Practices

| Do | Don't |
|----|-------|
| Use bounded cardinality labels | Use user IDs, email addresses, UUIDs |
| Keep label names consistent across services | Mix naming conventions (`env` vs `environment`) |
| Use `snake_case` for label names | Use `camelCase` or spaces |
| Limit to 10-15 labels per metric | Add every available dimension |
| Initialize metrics at startup | Let metrics appear only on first event |

### Reserved Labels

| Label | Source | Purpose |
|-------|--------|---------|
| `__name__` | Metric name | Internal; the metric name itself |
| `job` | Scrape config | Identifies the scrape job |
| `instance` | Scrape config | `host:port` of the scraped target |
| `__address__` | Service discovery | Pre-relabel target address |
| `__meta_*` | Service discovery | Metadata labels for relabeling |

## Naming Conventions

Format: `<namespace>_<name>_<unit>_<suffix>` (e.g., `http_requests_total`, `http_request_duration_seconds`)

| Rule | Example |
|------|---------|
| Use `_total` suffix for counters | `api_errors_total` |
| Use base units (seconds, bytes, meters) | `request_duration_seconds` (not milliseconds) |
| Use `snake_case` | `disk_io_read_bytes_total` |
| Prefix with subsystem/namespace | `myapp_cache_hits_total` |

## Related

- [PromQL](promql.md) - Querying the data model
- [Architecture](architecture.md) - How metrics flow through the system
- [Recording Rules](../patterns/recording-rules.md) - Pre-computing derived metrics
