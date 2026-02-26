# Log Monitoring Patterns

> **Purpose**: Loki + Grafana integration, LogQL patterns, log-metric correlation, alerting
> **MCP Validated**: 2026-02-19

## When to Use

- Centralizing application and infrastructure logs
- Correlating logs with metrics and traces
- Creating alerts based on log patterns
- Building log-derived metrics dashboards

## Loki Data Source Setup

```yaml
# provisioning/datasources/loki.yaml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    url: http://loki:3100
    jsonData:
      maxLines: 1000
      derivedFields:
        - datasourceUid: tempo-uid
          matcherRegex: '"traceID":"(\\w+)"'
          name: TraceID
          url: "$${__value.raw}"
```

## LogQL Query Patterns

### Stream Selection

```logql
{namespace="production", app="api-gateway"}   # Label filtering
{app=~"api-.*"}                               # Regex match
{namespace="production", app!="debug-tool"}   # Negation
```

### Line Filters (apply first -- fastest)

```logql
{app="api"} |= "error"                        # Contains
{app="api"} != "healthcheck"                   # Does not contain
{app="api"} |~ "status=(4|5)\\d{2}"           # Regex match
{app="api"} |= "error" != "timeout"           # Chained (AND)
```

### Parsers

```logql
{app="api"} | json                             # Auto-extract JSON fields
{app="api"} | json status="response.status"    # Specific JSON fields
{app="api"} | logfmt                           # Logfmt parser
{app="nginx"} | pattern `<ip> - - [<_>] "<method> <path> <_>" <status> <size>`
```

### Filtering Parsed Fields

```logql
{app="api"} | json | status >= 500
{app="api"} | json | status >= 400 | duration > 1s
{app="api"} | json | method = "POST" | path =~ "/api/v2/.*"
```

### Metric Queries (dashboards)

```logql
rate({app="api"} |= "error" [5m])                          # Error rate
sum by (status) (rate({app="api"} | json [5m]))             # Count by field
count_over_time({app="api"} | json | status >= 500 [1h])    # Count over time
quantile_over_time(0.95, {app="api"} | json | unwrap duration [5m]) by (endpoint)
bytes_rate({app="api"} [5m])                                # Throughput
topk(10, sum by (msg) (rate({app="api"} | json | level="error" [1h])))
```

## Log Dashboard Layout

```
Row: Overview (stat panels)
  [Log Volume /s] [Error Rate] [Warn Rate] [Unique Errors (1h)]
Row: Log Volume
  [Log Rate by Level - stacked bar] [Log Bytes Rate - time series]
Row: Errors
  [Error Logs - logs panel] [Top Error Messages - table]
Row: Full Logs
  [All Logs - logs panel with level, message columns]
```

### Variable Queries for Loki

```logql
label_values({}, namespace)                                  # Namespace
label_values({namespace="$namespace"}, app)                  # App
label_values({namespace="$namespace", app="$app"}, level)    # Level
```

## Correlating Logs with Metrics

**Derived Fields (Logs to Traces)**: Configure regex in Loki data source to extract trace IDs, then map to Tempo for automatic linking.

**Split View**: Use Grafana Explore with split view -- left panel for Prometheus metrics, right panel for Loki logs filtered to the same time range and service.

**Exemplars (Metrics to Traces)**: Configure Prometheus exemplars to link data points to trace IDs in Tempo.

## Log-Derived Metrics

Use Loki recording rules to generate Prometheus metrics from logs:

```yaml
# /etc/loki/rules/tenant/rules.yaml
groups:
  - name: log-derived-metrics
    interval: 1m
    rules:
      - record: app:http_errors:rate5m
        expr: sum by (app) (rate({namespace="production"} | json | status >= 500 [5m]))
      - record: app:log_volume:bytes_rate5m
        expr: sum by (app) (bytes_rate({namespace="production"} [5m]))
```

## Alerting on Log Patterns

```yaml
groups:
  - name: log-alerts
    rules:
      - alert: HighErrorLogRate
        expr: sum by (app) (rate({namespace="production"} |= "error" [5m])) > 10
        for: 5m
        labels: { severity: warning }
        annotations: { summary: "High error rate for {{ $labels.app }}" }
      - alert: FatalLogDetected
        expr: count_over_time({namespace="production"} |= "FATAL" [5m]) > 0
        for: 1m
        labels: { severity: critical }
      - alert: AuthFailureSpike
        expr: sum(rate({app="auth-service"} |= "authentication failed" [15m])) > 5
        for: 5m
        labels: { severity: warning }
```

## Label Best Practices

| Do | Don't |
|----|-------|
| Use static labels: `app`, `namespace`, `env` | High-cardinality: `user_id`, `request_id` |
| Keep label count low (< 10 per stream) | Create labels from every parsed field |
| Use line filters before parsers | Start with expensive regex parsers |
| Filter to specific streams first | Query `{}` across all streams |

## Best Practices

- **Filter early**: Stream selectors and line filters before parsers
- **Avoid high-cardinality labels**: Prevent index bloat
- **Use `unwrap` for numeric analysis**: Extract numeric fields from structured logs
- **Set up derived fields**: Link logs to traces for full correlation
- **Rate-limit ingestion**: Use Promtail pipeline stages to drop noisy logs

## Related

- [Data Sources](../concepts/data-sources.md) - Loki configuration
- [Alerting](../concepts/alerting.md) - Alert rule setup
- [Infrastructure Monitoring](infrastructure-monitoring.md) - Infrastructure patterns
- [Application Monitoring](application-monitoring.md) - Correlating logs with RED metrics
