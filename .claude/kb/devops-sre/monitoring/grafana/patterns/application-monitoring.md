# Application Monitoring Patterns

> **Purpose**: RED/USE methods, SLO/SLI dashboards, API and database monitoring
> **MCP Validated**: 2026-02-19

## When to Use

- Building service-level dashboards for application performance
- Implementing SLO/SLI tracking and error budgets
- Monitoring API latency, throughput, and error rates
- Tracking database query performance

## RED Method (Request-Driven Services)

**Rate, Errors, Duration** -- the standard for monitoring request-driven services.

```promql
# Rate (requests per second)
sum(rate(http_requests_total[5m])) by (service)

# Errors (error rate %)
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
  / sum(rate(http_requests_total[5m])) by (service) * 100

# Duration (latency percentiles)
histogram_quantile(0.50, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))
histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))
histogram_quantile(0.99, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))
```

### Dashboard Layout (RED)

```
Row: Overview (stat panels)
  [Request Rate /s] [Error Rate %] [p50] [p95] [p99]
Row: Rate
  [Rate by Service - time series] [Rate by Endpoint - time series]
Row: Errors
  [Error Rate % - time series] [Errors by Status Code - stacked bar]
Row: Latency
  [Latency Percentiles - time series] [Latency Distribution - heatmap]
```

## USE Method (Resource Services)

**Utilization, Saturation, Errors** -- for infrastructure resources.

```promql
# Utilization
rate(container_cpu_usage_seconds_total[5m]) / container_spec_cpu_quota * 100
# Saturation
rate(container_cpu_cfs_throttled_seconds_total[5m])
# Errors
rate(container_network_receive_errors_total[5m])
```

## SLO/SLI Dashboard Patterns

### Defining SLIs

| SLI Type | Metric | Target |
|----------|--------|--------|
| **Availability** | Successful / total requests | 99.9% |
| **Latency** | Requests under threshold / total | 95% under 300ms |
| **Throughput** | Successful ops per time unit | > 1000 req/s |

### SLO Dashboard Panels

```promql
# Availability SLI
1 - (sum(rate(http_requests_total{status=~"5.."}[30d]))
  / sum(rate(http_requests_total[30d])))

# Error budget remaining (%)
(1 - (sum(increase(http_requests_total{status=~"5.."}[30d]))
  / sum(increase(http_requests_total[30d]))) - 0.999) / 0.001 * 100

# Latency SLI (% under 300ms)
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
  / sum(rate(http_request_duration_seconds_count[5m])) * 100

# Burn rate (fast, 1h window)
sum(rate(http_requests_total{status=~"5.."}[1h]))
  / sum(rate(http_requests_total[1h])) / 0.001
```

### SLO Alert Rules

```yaml
groups:
  - name: slo-alerts
    rules:
      - alert: SLOFastBurn
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          / sum(rate(http_requests_total[1h])) > 14.4 * 0.001
        for: 2m
        labels: { severity: critical }
        annotations: { summary: "Burning error budget rapidly" }
      - alert: SLOSlowBurn
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[6h]))
          / sum(rate(http_requests_total[6h])) > 6 * 0.001
        for: 15m
        labels: { severity: warning }
```

## API Performance Dashboard

```promql
sum by (handler, method) (rate(http_requests_total[5m]))           # Rate by endpoint
histogram_quantile(0.95, sum by (le, handler)
  (rate(http_request_duration_seconds_bucket[5m]))) > 1            # Slow endpoints
sum by (handler) (rate(http_requests_total{status=~"5.."}[5m]))
  / sum by (handler) (rate(http_requests_total[5m])) * 100         # Error rate/endpoint
```

## Database Performance Dashboard

```promql
pg_stat_activity_count{state="active"}                              # Active connections
rate(pg_stat_statements_calls_total[5m])                            # Query rate
pg_stat_statements_mean_time_seconds > 1                            # Slow queries
pgbouncer_pools_server_active / pgbouncer_pools_server_maxconn * 100 # Pool utilization
pg_replication_lag_seconds                                          # Replication lag
```

## Custom Application Metrics

```python
from prometheus_client import Counter, Histogram

REQUEST_COUNT = Counter('app_requests_total', 'Total requests',
                        ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Latency',
                            ['method', 'endpoint'],
                            buckets=[.01, .05, .1, .25, .5, 1.0, 2.5, 5.0, 10.0])
```

## Best Practices

- **Start with RED**: Every service needs rate, error, and duration panels
- **Use histogram_quantile**: Prefer percentiles over averages for latency
- **Set SLO targets before alerts**: Define "good" before alerting on "bad"
- **Include business context**: Add panels for business metrics (orders/min)
- **Use multi-burn-rate alerts**: Fast burn for pages, slow burn for tickets

## Related

- [Infrastructure Monitoring](infrastructure-monitoring.md) - Server/cluster monitoring
- [Dashboards and Panels](../concepts/dashboards-panels.md) - Panel configuration
- [Alerting](../concepts/alerting.md) - Alert rule setup
