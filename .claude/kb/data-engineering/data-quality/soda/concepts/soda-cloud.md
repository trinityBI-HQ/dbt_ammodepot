# Soda Cloud

> **Purpose**: SaaS platform for data monitoring, alerting, contracts, and collaboration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Soda Cloud is the SaaS layer that extends Soda Core with centralized monitoring, ML-powered anomaly detection, incident management, data contracts, and team collaboration. It receives scan results from Soda Core or Soda Agent and provides a web UI for data quality oversight.

## Architecture

```
Soda Core (CLI/Python)  -->  Soda Cloud (SaaS)
Soda Agent (Hosted/K8s) -->      |
                             Dashboard / Alerts / Incidents
```

**Deployment options:**
- **Soda Core**: Open-source, runs locally or in pipelines
- **Soda-hosted Agent**: Managed by Soda, no setup required
- **Self-hosted Agent**: Runs in your Kubernetes cluster, data stays on-premises

## Key Features

### Data Contracts

Formal agreements between data producers and consumers:

- Define expected schema, data types, value ranges, constraints
- Codify quality expectations as enforceable checks
- Assign ownership and accountability to datasets
- Integrate with CI/CD to block bad data before production

### Anomaly Detection

ML-powered monitoring that detects unexpected changes:

- Automatically learns historical patterns for metrics
- Alerts when values deviate from established baselines
- Smart Anomaly Treatment selects optimal historical windows
- No manual threshold definition required (unlike rule-based checks)

### Incidents

Workflow for triaging and resolving data quality issues:

- Auto-created when checks fail beyond thresholds
- Assign to team members for investigation
- Track resolution status and root cause
- Integrate with Jira, ServiceNow, PagerDuty via webhooks

### Agreements

Collaborative quality contracts requiring stakeholder approval:

- Define scan schedules and quality expectations
- Require stakeholder sign-off before activation
- Scans do not run until all parties approve
- Track agreement compliance over time

### Check Dashboard

Centralized view of all data quality checks:

- Historical pass/fail trends per dataset
- Metric time-series graphs
- Filter by data source, severity, status
- Drill down into individual scan results

## Webhook Integrations

```
Soda Cloud --> Webhook --> Slack / Jira / PagerDuty / ServiceNow
```

Webhooks support:
- Alert notifications on warn/fail check results
- Incident creation and updates
- Agreement lifecycle events (created, updated, removed)

Requirements for webhook endpoints:
- HTTPS with TLS 1.2+
- Return HTTP 200-400
- Respond within 10 seconds

## Connecting Soda Core to Cloud

```yaml
# In configuration.yml
soda_cloud:
  host: cloud.soda.io
  api_key_id: ${SODA_CLOUD_API_KEY}
  api_key_secret: ${SODA_CLOUD_API_SECRET}
```

Once configured, every `soda scan` automatically pushes results to Soda Cloud.

## Free vs Paid Tiers

| Feature | Soda Core (Free) | Soda Cloud |
|---------|-------------------|------------|
| SodaCL checks | Yes | Yes |
| CLI scans | Yes | Yes |
| Anomaly detection | No | Yes (ML) |
| Data contracts | Limited | Full |
| Incidents | No | Yes |
| Agreements | No | Yes |
| Dashboards | No | Yes |
| Webhooks/alerts | No | Yes |
| Team collaboration | No | Yes |

## Related

- [Checks](../concepts/checks.md)
- [Monitoring and Alerting](../patterns/monitoring-alerting.md)
- [CI/CD Integration](../patterns/ci-cd-integration.md)
