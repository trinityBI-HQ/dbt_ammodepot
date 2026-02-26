# Data Sources

> **Purpose**: Data source configuration, query languages, and provisioning
> **MCP Validated**: 2026-02-19

## Overview

Data sources are the backends that Grafana queries for metrics, logs, and traces. Grafana ships with built-in support for Prometheus, Loki, Tempo, and many others, with 150+ plugins available.

## Built-in vs Plugin Data Sources

| Category | Built-in | Plugin |
|----------|----------|--------|
| **Metrics** | Prometheus, InfluxDB, Graphite | Datadog, New Relic |
| **Logs** | Loki, Elasticsearch | Splunk, Graylog |
| **Traces** | Tempo, Jaeger, Zipkin | Honeycomb |
| **SQL** | PostgreSQL, MySQL, MSSQL | Snowflake, BigQuery |
| **Cloud** | CloudWatch, Azure Monitor | Google Cloud Monitoring |

## Prometheus Data Source

The most common Grafana data source. Queries use PromQL.

```yaml
# /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      httpMethod: POST
      timeInterval: 15s   # Scrape interval (for $__rate_interval)
```

### Essential PromQL

```promql
up{job="api-server"}                                          # Instant vector
rate(http_requests_total{job="api"}[5m])                      # Rate (counter/sec)
sum by (service) (rate(http_requests_total[5m]))              # Aggregation
histogram_quantile(0.99, sum by (le) (rate(duration_bucket[5m])))  # p99 latency
predict_linear(node_filesystem_avail_bytes[6h], 4*3600)       # Prediction
```

**Tip**: Use `$__rate_interval` instead of hardcoded `[5m]` in Grafana. It adjusts based on scrape interval and time range.

## Loki Data Source

For log aggregation. Queries use LogQL.

```yaml
datasources:
  - name: Loki
    type: loki
    url: http://loki:3100
    jsonData:
      derivedFields:
        - datasourceUid: tempo-uid
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
```

### LogQL Basics

```logql
{namespace="production", app="api"}           # Stream selector
{app="api"} |= "error" != "timeout"          # Line filters
{app="api"} | json | status >= 500           # Parser + filter
rate({app="api"} |= "error" [5m])            # Metric query
```

See [Log Monitoring pattern](../patterns/log-monitoring.md) for advanced LogQL.

## SQL Data Sources

PostgreSQL, MySQL, and MSSQL share a similar SQL query interface.

```sql
SELECT
  $__timeGroup(created_at, '1h') AS time,
  count(*) AS orders
FROM orders
WHERE $__timeFilter(created_at) AND region = '$region'
GROUP BY 1 ORDER BY 1
```

**Macros:**

| Macro | Purpose |
|-------|---------|
| `$__timeFilter(col)` | Time range filter |
| `$__timeGroup(col, '1h')` | Time bucketing |
| `$__unixEpochFilter(col)` | Unix timestamp filter |

## Mixed Data Sources

Use the **Mixed** data source to combine queries from multiple sources in one panel. Each query target specifies a different source. Use transformations (Join by field) to correlate results.

## Data Source Provisioning

```yaml
# /etc/grafana/provisioning/datasources/all.yaml
apiVersion: 1
deleteDatasources:
  - { name: OldPrometheus, orgId: 1 }
datasources:
  - { name: Prometheus, type: prometheus, url: "http://prometheus:9090", isDefault: true }
  - { name: Loki, type: loki, url: "http://loki:3100" }
  - { name: Tempo, type: tempo, url: "http://tempo:3200" }
```

Mount in Docker/Kubernetes: `./provisioning:/etc/grafana/provisioning`

## Best Practices

- **Use `proxy` access mode**: Routes queries through the Grafana server
- **Set `isDefault: true`** on your primary metrics source
- **Configure derived fields**: Link Loki logs to Tempo traces via trace ID
- **Use provisioning**: Keep data source config in version control
- **Set `timeInterval`**: Ensures `$__rate_interval` calculates correctly

## Related

- [Dashboards and Panels](dashboards-panels.md) - Visualize data source queries
- [Alerting](alerting.md) - Create alert rules on data source queries
- [Infrastructure Monitoring](../patterns/infrastructure-monitoring.md) - Prometheus patterns
