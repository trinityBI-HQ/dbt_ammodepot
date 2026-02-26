# Prometheus Alerting

> **Purpose**: Alertmanager architecture, alert rules, routing, silencing, and inhibition
> **MCP Validated**: 2026-02-20

## Overview

Prometheus alerting is a two-component system: **Prometheus server** evaluates alert rules and sends firing alerts to **Alertmanager**, which handles deduplication, grouping, routing, silencing, and notification delivery.

## Architecture

```
Prometheus Server                    Alertmanager
┌──────────────────┐                ┌───────────────────────┐
│ Alert Rules      │  firing/       │ Deduplication         │
│ (PromQL + for)   │──resolved────> │ Grouping              │
│                  │  via HTTP      │ Routing (label match) │
│ Evaluation every │                │ Silencing / Inhibition│
│ group interval   │                │ Notification          │
└──────────────────┘                └──────┬────────────────┘
                                           │
                              ┌────────────┼────────────────┐
                              v            v                v
                          [Slack]     [PagerDuty]       [Email]
```

## Alert Rules

Alert rules are defined in rule files referenced from `prometheus.yml`:

```yaml
# prometheus.yml
rule_files:
  - "rules/alerts/*.yml"
```

### Rule Structure

```yaml
groups:
  - name: service-alerts
    interval: 1m                    # Evaluation frequency
    rules:
      - alert: HighErrorRate
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m])) > 0.05
        for: 5m                     # Must fire continuously for 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Error rate > 5% for {{ $labels.service }}"
          description: "Current error rate: {{ $value | humanizePercentage }}"
          runbook_url: "https://wiki.example.com/runbooks/high-error-rate"
          dashboard_url: "https://grafana.example.com/d/svc/{{ $labels.service }}"
```

### Alert States

| State | Meaning |
|-------|---------|
| **Inactive** | Condition is false |
| **Pending** | Condition is true, `for` duration not yet elapsed |
| **Firing** | Condition true for the `for` duration, sent to Alertmanager |

## Alertmanager Configuration

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: "https://hooks.slack.com/services/XXX"

route:
  receiver: default-email
  group_by: [alertname, cluster, service]
  group_wait: 30s            # Wait before first notification
  group_interval: 5m         # Wait between group notifications
  repeat_interval: 4h        # Resend if still firing
  routes:
    - receiver: pagerduty-critical
      matchers:
        - severity = critical
      group_wait: 10s
      repeat_interval: 1h
    - receiver: slack-warnings
      matchers:
        - severity = warning
      continue: true          # Keep matching subsequent routes

receivers:
  - name: default-email
    email_configs:
      - to: "ops@example.com"
  - name: pagerduty-critical
    pagerduty_configs:
      - service_key: "<key>"
        severity: "{{ .CommonLabels.severity }}"
  - name: slack-warnings
    slack_configs:
      - channel: "#alerts"
        title: "{{ .CommonLabels.alertname }}"
        text: "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}"
```

## Routing

Routes form a tree. Alerts are matched top-to-bottom; first match wins (unless `continue: true`).

| Field | Purpose |
|-------|---------|
| `group_by` | Labels used to group alerts into single notifications |
| `group_wait` | Buffer time before sending first notification for a group |
| `group_interval` | Minimum wait between notifications for same group |
| `repeat_interval` | How often to resend if alert is still firing |
| `matchers` | Label conditions for route matching |
| `continue` | If true, keep evaluating sibling routes after match |

## Inhibition

Suppress lower-severity alerts when a higher-severity alert is firing for the same target:

```yaml
inhibit_rules:
  - source_matchers:
      - severity = critical
    target_matchers:
      - severity = warning
    equal: [alertname, cluster, service]
```

This suppresses `warning` alerts when a `critical` alert fires for the same `alertname`, `cluster`, and `service`.

## Silences

Temporary suppression of alerts during maintenance. Managed via Alertmanager UI or `amtool`:

```bash
amtool silence add alertname="HighCPU" instance="node1:9100" --comment="Maintenance" --duration=2h
amtool silence query                    # List active silences
amtool silence expire <silence-id>      # Expire a silence
```

Template functions for annotations: `humanize`, `humanizePercentage`, `humanizeDuration`, `title`.

## Related

- [Alerting Patterns](../patterns/alerting-patterns.md) - Alert design best practices
- [PromQL](promql.md) - Query language for alert expressions
