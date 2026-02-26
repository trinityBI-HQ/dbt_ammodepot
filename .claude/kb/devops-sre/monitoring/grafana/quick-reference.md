# Grafana Quick Reference

> Fast lookup tables. For detailed examples, see linked files.
> **MCP Validated**: 2026-02-19

## Panel Types

| Panel | Use Case | Data Format |
|-------|----------|-------------|
| Time series | Metrics over time | Time-value pairs |
| Stat | Single value highlight | Scalar/last value |
| Gauge | Value vs threshold | Scalar with min/max |
| Table | Tabular data | Rows and columns |
| Bar chart | Categorical comparison | Labels + values |
| Heatmap | Density distribution | Bucketed time series |
| Logs | Log stream display | Loki/Elasticsearch |
| Node graph | Service topology | Nodes + edges |
| Canvas | Custom layout | Any (drag-and-drop) |

## Data Source Types

| Source | Query Language | Best For |
|--------|---------------|----------|
| Prometheus | PromQL | Infrastructure metrics |
| Loki | LogQL | Log aggregation |
| Tempo | TraceQL | Distributed tracing |
| InfluxDB | InfluxQL/Flux | Time series IoT |
| PostgreSQL / MySQL | SQL | Relational data |
| Elasticsearch | Lucene/KQL | Logs and search |
| CloudWatch | CloudWatch syntax | AWS metrics |

## Essential PromQL

```promql
rate(http_requests_total[5m])                                                    # Request rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])     # Error ratio
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))          # p95 latency
100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)    # CPU %
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100          # Memory %
```

## Variable Syntax

| Syntax | Description | Example |
|--------|-------------|---------|
| `$var` | Simple reference | `instance =~ "$instance"` |
| `${var}` | Explicit boundary | `${namespace}_total` |
| `${var:csv}` | Comma-separated | `status=~"${status:csv}"` |
| `${var:pipe}` | Pipe-separated | `host=~"${host:pipe}"` |
| `${var:regex}` | Regex-escaped | Safe for regex filters |
| `${__from:date}` | Time range start | Dashboard time range |

## Dashboard JSON Key Fields

```json
{ "uid": "unique-id", "title": "Dashboard Title",
  "panels": [{ "type": "timeseries", "gridPos": {"h":8,"w":12,"x":0,"y":0},
    "targets": [{"expr": "rate(http_requests_total[5m])"}] }],
  "templating": { "list": [{"name":"namespace","type":"query"}] },
  "time": { "from": "now-6h", "to": "now" } }
```

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use `rate()` on gauges | Use `rate()` only on counters |
| Set alerts on raw counters | Alert on `rate()` or `increase()` |
| Create one huge dashboard | Split by concern (infra, app, business) |
| Hardcode label values | Use template variables for flexibility |
| Ignore time range in queries | Use `$__rate_interval` for rate queries |
| Skip dashboard folders | Organize by team/service |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `e` | Toggle panel edit |
| `v` | View panel fullscreen |
| `Ctrl+S` | Save dashboard |
| `Esc` | Exit edit/fullscreen |
| `?` | Show all shortcuts |

## Related

| Topic | Path |
|-------|------|
| Dashboard & panels | `concepts/dashboards-panels.md` |
| Data sources | `concepts/data-sources.md` |
| Alerting | `concepts/alerting.md` |
| Full index | `index.md` |
