# Grafana Alerting

> **Purpose**: Unified alerting system -- alert rules, contact points, notification policies
> **MCP Validated**: 2026-02-19

## Overview

Grafana Alerting (unified alerting, Grafana 9+) replaces legacy per-panel alerting. It provides centralized alert management with multi-dimensional rules, flexible routing, and external alertmanager integration.

## Architecture

```
Alert Rule (query + condition) -> Alert Instance (per label set)
  -> Notification Policy (routing tree) -> Contact Point (delivery)
  -> Silences / Mute Timings (suppression)
```

## Alert Rules

| Type | Data Source | Use Case |
|------|-----------|----------|
| **Grafana-managed** | Any data source | Multi-source, Loki, SQL |
| **Data source-managed** | Prometheus/Mimir | PromQL recording + alerting |

### Multi-Dimensional Alerts

A single rule produces multiple instances, one per label combination:

```yaml
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
# Fires separately for each {service, endpoint} combination
```

### Rule Structure

```yaml
name: High Error Rate
condition: C
data:
  - refId: A
    datasourceUid: prometheus-uid
    model:
      expr: rate(http_requests_total{status=~"5.."}[5m])
  - refId: B                        # Reduce
    datasourceUid: __expr__
    model: { type: reduce, expression: A, reducer: last }
  - refId: C                        # Threshold
    datasourceUid: __expr__
    model:
      type: threshold
      expression: B
      conditions:
        - evaluator: { type: gt, params: [0.05] }
for: 5m
labels:
  severity: critical
annotations:
  summary: "Error rate above 5% for {{ $labels.service }}"
  runbook_url: "https://wiki.example.com/runbooks/high-error-rate"
```

Rules are organized into **evaluation groups** with an interval (e.g., 1m) and folder (permission boundary).

## Contact Points

| Type | Configuration |
|------|---------------|
| **Email** | SMTP server, recipients |
| **Slack** | Webhook URL or bot token + channel |
| **PagerDuty** | Integration key (Events API v2) |
| **Webhook** | HTTP endpoint, headers, body |
| **OpsGenie** | API key, responders |

### Notification Templates

```go
{{ define "custom.message" }}
{{ range .Alerts }}
Service: {{ .Labels.service }} | Value: {{ .Values.B }}
{{ end }}
{{ end }}
```

## Notification Policies

Routing tree that matches alerts to contact points by labels:

```yaml
receiver: email-ops               # Root catch-all
group_by: [alertname, cluster]
group_wait: 30s
group_interval: 5m
repeat_interval: 4h
routes:
  - receiver: slack-platform
    matchers: [team = platform]
    continue: false
  - receiver: pagerduty-critical
    matchers: [severity = critical]
    group_wait: 10s
    repeat_interval: 1h
```

**Key fields:** `group_by` (group alerts), `group_wait` (buffer time), `continue` (keep routing if true).

## Silences and Mute Timings

**Silences**: Temporary suppression with label matchers and duration (planned maintenance, known issues).

**Mute Timings**: Recurring schedules for suppression:

```yaml
mute_timings:
  - name: weekend-maintenance
    time_intervals:
      - weekdays: [saturday, sunday]
        times: [{ start_time: "02:00", end_time: "06:00" }]
```

## Labels and Annotations

| Field | Purpose | Example |
|-------|---------|---------|
| **Labels** | Routing, grouping, dedup | `severity=critical`, `team=platform` |
| **Annotations** | Human-readable context | `summary`, `runbook_url` |

Annotations support templates: `"CPU at {{ $values.B }}% on {{ $labels.instance }}"`

## Best Practices

- **Alert on symptoms**: User-facing impact (latency, errors) over internal state
- **Use `for` duration**: Require sustained firing (e.g., 5m) to avoid flapping
- **Add runbook URLs**: Every critical alert links to remediation steps
- **Group intelligently**: By `alertname` + service-level label, not by instance
- **Tune thresholds**: Review monthly to reduce alert fatigue
- **Use mute timings**: Suppress known maintenance windows proactively

## Related

- [Data Sources](data-sources.md) - Query languages for alert rules
- [Infrastructure Monitoring](../patterns/infrastructure-monitoring.md) - Alert examples
- [Application Monitoring](../patterns/application-monitoring.md) - SLO-based alerting
