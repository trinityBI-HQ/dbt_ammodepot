# Alerting Patterns

> **Purpose**: Alert design best practices, severity levels, runbook integration, and escalation patterns
> **MCP Validated**: 2026-02-20

## When to Use

- Designing alert rules for production systems
- Establishing severity levels and escalation policies
- Reducing alert fatigue while maintaining incident detection

## Alert Design Principles

### Alert on Symptoms, Not Causes

| Symptom (Good) | Cause (Avoid) |
|-----------------|---------------|
| Error rate > 5% | Database connection pool full |
| Latency p95 > 2s | CPU usage > 80% |
| Request queue depth growing | Memory > 90% |
| SLO burn rate exceeded | Disk I/O latency high |

Alert on what users experience. Cause-based alerts generate noise when the system self-heals.

### The Four Golden Signals

```yaml
groups:
  - name: golden-signals
    rules:
      # Latency - How long requests take
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum by (le, service)
            (rate(http_request_duration_seconds_bucket[5m]))) > 0.5
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "p95 latency > 500ms for {{ $labels.service }}"

      # Traffic - How much demand is hitting the system
      - alert: TrafficAnomaly
        expr: |
          sum by (service) (rate(http_requests_total[5m]))
          < 0.1 * sum by (service) (rate(http_requests_total[5m] offset 1h))
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "Traffic dropped >90% for {{ $labels.service }}"

      # Errors - Rate of failed requests
      - alert: HighErrorRate
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels: { severity: critical }
        annotations:
          summary: "Error rate > 5% for {{ $labels.service }}"

      # Saturation - How full the system is
      - alert: HighSaturation
        expr: |
          (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.90
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "Memory > 90% on {{ $labels.instance }}"
```

## Severity Levels

| Level | Response Time | Channel | Use Case |
|-------|---------------|---------|----------|
| `critical` | < 15 min | PagerDuty (page) | User-facing outage, data loss risk |
| `warning` | < 4 hours | Slack channel | Degraded performance, approaching limits |
| `info` | Next business day | Email / dashboard | Capacity planning, non-urgent |

### Severity Assignment Rules

```yaml
# Critical: user-facing impact, requires immediate action
- alert: ServiceDown
  expr: up{job="api"} == 0
  for: 2m
  labels: { severity: critical }

# Warning: degraded but functional, needs attention soon
- alert: HighCPU
  expr: |
    100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
  for: 15m
  labels: { severity: warning }

# Info: awareness only, no action required
- alert: CertificateExpiringSoon
  expr: probe_ssl_earliest_cert_expiry - time() < 30 * 86400
  for: 1h
  labels: { severity: info }
```

## Runbook Integration

Every critical and warning alert should include `runbook_url` and `dashboard_url` annotations:

```yaml
annotations:
  summary: "High error rate on {{ $labels.service }}: {{ $value | humanizePercentage }}"
  runbook_url: "https://wiki.example.com/runbooks/{{ $labels.alertname | toLower }}"
  dashboard_url: "https://grafana.example.com/d/svc?var-service={{ $labels.service }}"
```

Runbooks should cover: impact, investigation steps (dashboards, deployment history, dependencies, logs), and remediation actions (rollback, scaling, dependency checks).

## SLO-Based Alerting (Burn Rate)

Alert when the error budget burn rate indicates the SLO will be breached:

```yaml
groups:
  - name: slo-burn-rate
    rules:
      # Pre-compute error ratio
      - record: slo:error_ratio:rate5m
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m]))

      # Fast burn (1h window) - page immediately
      - alert: SLOBurnRateCritical
        expr: slo:error_ratio:rate5m > (14.4 * 0.001)
        for: 2m
        labels: { severity: critical }
        annotations:
          summary: "SLO burn rate critical for {{ $labels.service }}"

      # Slow burn (6h window) - ticket
      - alert: SLOBurnRateWarning
        expr: slo:error_ratio:rate5m > (6 * 0.001)
        for: 30m
        labels: { severity: warning }
```

## Alertmanager Routing Pattern

```yaml
route:
  receiver: default
  group_by: [alertname, cluster]
  routes:
    # Critical -> PagerDuty immediately
    - receiver: pagerduty
      matchers: [severity = critical]
      group_wait: 10s
      repeat_interval: 1h
    # Warning -> Slack with reasonable grouping
    - receiver: slack-platform
      matchers: [severity = warning, team = platform]
      group_wait: 1m
      repeat_interval: 4h
    # Info -> email digest
    - receiver: email-digest
      matchers: [severity = info]
      group_wait: 10m
      repeat_interval: 24h

inhibit_rules:
  # Critical suppresses warning for same alert+service
  - source_matchers: [severity = critical]
    target_matchers: [severity = warning]
    equal: [alertname, service]
  # Cluster-down suppresses all per-node alerts
  - source_matchers: [alertname = ClusterDown]
    target_matchers: [severity =~ "warning|info"]
    equal: [cluster]
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| No `for` clause | Alerts on transient spikes | Use `for: 5m` minimum |
| Alert on raw counters | Counter always increases | Use `rate()` or `increase()` |
| Too many critical alerts | Alert fatigue, ignored pages | Reserve critical for user-facing outages |
| No runbook link | Responders lack context | Add `runbook_url` to every alert |
| Alerting on every metric | Noise overwhelms signal | Alert on golden signals only |
| Same threshold for all envs | Dev noise, prod gaps | Use env-specific thresholds |

## Best Practices

- **Use `for` duration**: Require 5-15 minutes of sustained firing to filter noise
- **Group intelligently**: Group by `alertname` + service label, not by instance
- **Review monthly**: Audit alert frequency, tune thresholds, retire stale alerts
- **Use inhibition**: Suppress lower-severity when higher-severity fires for same target
- **Test alert rules**: Use `promtool check rules` and unit testing
- **Limit critical alerts**: If everything is critical, nothing is

## Related

- [Alerting Concepts](../concepts/alerting.md) | [Recording Rules](recording-rules.md)
