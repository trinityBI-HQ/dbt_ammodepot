# Dashboards and Panels

> **Purpose**: Core dashboard structure, panel types, variables, and visualization options
> **MCP Validated**: 2026-02-19

## Overview

A Grafana dashboard is a collection of panels organized in rows, each querying one or more data sources and rendering visualizations. Dashboards support variables for dynamic filtering, annotations for event correlation, and links for navigation.

## Dashboard Structure

```
Dashboard
├── Settings (time range, refresh, variables, links)
├── Rows (collapsible grouping)
│   ├── Panel 1 (visualization + query + overrides)
│   └── Panel N
├── Annotations (event markers on time axis)
└── Links (navigation to other dashboards/URLs)
```

**Key properties:** UID (stable identifier), tags (search/filter), folder (permissions), time range (global picker), refresh interval (auto-refresh frequency).

## Panel Types

| Panel | Best For | Example |
|-------|----------|---------|
| **Time series** | Metrics over time | CPU usage, request rate |
| **Stat** | Single KPI highlight | Total requests, uptime % |
| **Gauge** | Value against threshold | Disk usage, SLO attainment |
| **Table** | Multi-column data | Top endpoints, error breakdown |
| **Bar chart** | Category comparison | Requests by service |
| **Heatmap** | Distribution over time | Latency distribution buckets |
| **Logs** | Log stream viewing | Application logs from Loki |
| **Node graph** | Service dependencies | Trace service map |
| **Canvas** | Custom free-form layout | Network diagrams |

## Visualization Options

### Thresholds

Set color boundaries on stat, gauge, and time series panels:

```yaml
thresholds:
  mode: absolute    # or "percentage"
  steps:
    - { color: green, value: null }   # base
    - { color: yellow, value: 70 }
    - { color: red, value: 90 }
```

### Overrides

Override field-level settings by field name or regex:

```yaml
overrides:
  - matcher: { id: byName, options: "errors" }
    properties:
      - { id: color, value: { fixedColor: red, mode: fixed } }
```

### Transformations

| Transformation | Use Case |
|----------------|----------|
| **Filter by name** | Show/hide specific series |
| **Organize fields** | Reorder, rename, hide columns |
| **Join by field** | Merge multiple queries by time/label |
| **Calculate field** | Add computed columns (reduce, binary ops) |
| **Group by** | Aggregate rows by label value |

## Template Variables

### Variable Types

| Type | Source | Example |
|------|--------|---------|
| **Query** | Data source query | `label_values(up, namespace)` |
| **Custom** | Static list | `production, staging, development` |
| **Datasource** | Available data sources | Switch between Prometheus instances |
| **Interval** | Time interval | `$__interval`, `1m`, `5m`, `1h` |
| **Text box** | Free text input | User-entered filter string |

### Chaining Variables

Variables can depend on each other for cascading filters:

```
$cluster  ->  label_values(up{cluster="$cluster"}, namespace)
$namespace -> label_values(up{namespace="$namespace"}, pod)
```

## Time Range Controls

| Feature | Description |
|---------|-------------|
| **Global picker** | Top-right; applies to all panels by default |
| **Relative time** | `now-6h`, `now-1d`, `now-7d` |
| **Panel override** | Per-panel relative time |
| **Time shift** | Compare current vs previous period |
| **Zoom** | Click-drag on time series to zoom |

## Dashboard Linking

| Link Type | Configuration |
|-----------|---------------|
| **Dashboard link** | Settings > Links > pass variables through |
| **Data link** | Panel > Field > Data links > URL with `${__value.raw}` |
| **Drilldown** | Pass `var-name=value` in URL query parameters |

Example: `/d/app-detail/app?var-service=${__field.labels.service}&from=${__from}&to=${__to}`

## Best Practices

- **One concern per dashboard**: Separate infrastructure, application, and business
- **Use variables**: Never hardcode cluster, namespace, or instance values
- **Set meaningful titles**: Describe what the metric means, not the query
- **Group with rows**: Use collapsible rows to organize large dashboards
- **Standard units**: Always set units (bytes, seconds, percent) for readability

## Related

- [Data Sources](data-sources.md) - Configuring data backends
- [Quick Reference](../quick-reference.md) - Panel type and variable syntax tables
- [Application Monitoring](../patterns/application-monitoring.md) - Dashboard design patterns
