# PromQL Query Language

> **Purpose**: Fundamentals of PromQL selectors, functions, operators, and query patterns
> **MCP Validated**: 2026-02-20

## Overview

PromQL is a functional, read-only query language for selecting, filtering, aggregating, and transforming time series data. Returns four types: instant vector, range vector, scalar, and string.

## Data Types

| Type | Description | Example |
|------|-------------|---------|
| **Instant vector** | Single sample per series at one timestamp | `up{job="api"}` |
| **Range vector** | Range of samples per series over time window | `http_requests_total[5m]` |
| **Scalar** | Single numeric value | `42`, `rate(...)[0]` |
| **String** | String literal (rarely used) | `"hello"` |

## Selectors

```promql
# Instant vector selector
http_requests_total{method="GET", status=~"2.."}

# Range vector selector
http_requests_total{job="api"}[5m]

# Offset modifier (look back in time)
http_requests_total offset 1h

# @ modifier (query at specific timestamp)
http_requests_total @ 1708348800
```

## Operators

### Arithmetic

```promql
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes    # Subtraction
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
  / node_memory_MemTotal_bytes * 100                            # Memory usage %
```

### Comparison (returns matching series or filters)

```promql
http_requests_total > 1000                     # Filter: keep series where value > 1000
http_requests_total > bool 1000                # Returns 1 or 0 per series
```

### Logical (set operations on instant vectors)

```promql
up{job="api"} and on(instance) http_requests_total    # Intersection
up{job="api"} or up{job="worker"}                     # Union
up{job="api"} unless on(instance) alerting_targets     # Difference
```

### Vector Matching

```promql
# one-to-one (default)
rate(errors_total[5m]) / rate(requests_total[5m])

# many-to-one with group_left
rate(errors_total[5m]) / on(instance) group_left(version) rate(requests_total[5m])

# Ignoring specific labels
rate(errors_total[5m]) / ignoring(status) rate(requests_total[5m])
```

## Aggregation Operators

```promql
sum by (job) (rate(http_requests_total[5m]))           # Sum per job
avg without (instance) (rate(cpu_usage[5m]))           # Avg, dropping instance
count by (namespace) (kube_pod_info)                   # Count series
topk(5, sum by (service) (rate(errors_total[5m])))     # Top 5 error services
quantile(0.95, rate(request_duration_seconds[5m]))     # 95th percentile
```

`by` keeps only listed labels. `without` drops listed labels and keeps the rest.

## Functions Reference

### Rate and Change

| Function | Input | Purpose |
|----------|-------|---------|
| `rate(v[t])` | Counter | Per-second average rate over window |
| `irate(v[t])` | Counter | Instantaneous rate (last two points) |
| `increase(v[t])` | Counter | Total increase over window |
| `delta(v[t])` | Gauge | Difference between first and last |
| `deriv(v[t])` | Gauge | Per-second derivative (linear regression) |
| `changes(v[t])` | Gauge | Number of value changes |

### Aggregation Over Time

| Function | Purpose |
|----------|---------|
| `avg_over_time(v[t])` | Mean over range |
| `min_over_time(v[t])` | Minimum over range |
| `max_over_time(v[t])` | Maximum over range |
| `sum_over_time(v[t])` | Sum over range |
| `quantile_over_time(q, v[t])` | Quantile over range |
| `last_over_time(v[t])` | Most recent value in range |

### Histogram

```promql
histogram_quantile(0.99, rate(request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, sum by (le, service) (rate(request_duration_seconds_bucket[5m])))
```

### Utility

| Function | Purpose | Example |
|----------|---------|---------|
| `absent(v)` | Returns 1 if vector is empty | `absent(up{job="api"})` |
| `absent_over_time(v[t])` | Returns 1 if no samples in range | `absent_over_time(up[5m])` |
| `label_replace()` | Regex-based label manipulation | `label_replace(up, "host", "$1", "instance", "(.*):.*")` |
| `label_join()` | Concatenate label values | `label_join(up, "addr", ":", "instance", "port")` |
| `predict_linear(v[t], s)` | Linear extrapolation | `predict_linear(disk_free[6h], 3600*24)` |
| `resets(v[t])` | Count counter resets | `resets(http_requests_total[1h])` |
| `clamp(v, min, max)` | Clamp values to range | `clamp(cpu_percent, 0, 100)` |
| `sgn(v)` | Sign of value (-1, 0, 1) | `sgn(temperature_delta)` |

## Subquery Syntax

```promql
# Subquery: evaluate inner expression as range vector
max_over_time(rate(http_requests_total[5m])[1h:1m])
#                                           ^   ^
#                                         range resolution
```

## Best Practices

- Always use `rate()` (not `irate()`) for alerting -- `irate()` is too volatile
- Use `$__rate_interval` in Grafana instead of hardcoded ranges
- Range vector window should be at least 4x the scrape interval
- Use `by` clauses explicitly to avoid unexpected aggregation
- Combine `absent()` with alerts to detect missing targets
- Prefer `histogram_quantile()` over summary quantiles for aggregation

## Related

- [Data Model](data-model.md) - Metric types and labels
- [Recording Rules](../patterns/recording-rules.md) - Pre-computing expensive queries
