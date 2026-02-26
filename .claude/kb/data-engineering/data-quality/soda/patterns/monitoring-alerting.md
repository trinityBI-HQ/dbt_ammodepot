# Monitoring and Alerting

> **Purpose**: Setting up data quality monitoring, alerts, incidents, and SLAs with Soda
> **MCP Validated**: 2026-02-19

## When to Use

- Production data quality monitoring with alerting
- Defining SLAs for data freshness, completeness, and accuracy
- Routing incidents to Slack, Jira, or PagerDuty
- Building progressive alerting with warn/fail thresholds

## Alert Levels

### Warn and Fail Thresholds

```yaml
checks for orders:
  # Progressive alerting: warn early, fail on breach
  - row_count:
      warn: when < 1000
      fail: when < 100

  - missing_count(customer_id):
      warn: when > 0
      fail: when > 10

  - freshness(created_at):
      warn: when > 6h
      fail: when > 24h

  - duplicate_percent(order_id):
      warn: when > 0.1%
      fail: when > 1%
```

**Behavior:**
- **Pass**: All thresholds met
- **Warn**: Warning threshold breached, scan continues
- **Fail**: Failure threshold breached, scan reports failure

## Soda Cloud Monitoring

### Dashboard Setup

Soda Cloud provides automatic dashboards when configured:

```yaml
# configuration.yml - connect to Soda Cloud
soda_cloud:
  host: cloud.soda.io
  api_key_id: ${SODA_CLOUD_API_KEY}
  api_key_secret: ${SODA_CLOUD_API_SECRET}
```

Every `soda scan` pushes results to Soda Cloud, where you get:
- Historical pass/fail trends per dataset
- Metric time-series charts
- Check failure drill-downs
- Team-wide quality overview

### Anomaly Detection (Soda Cloud)

ML-powered monitoring that learns from historical data:

```yaml
checks for orders:
  # Soda Cloud detects anomalies automatically
  - anomaly detection for row_count
  - anomaly detection for avg(order_value)
  - anomaly detection for missing_percent(email)
```

Smart Anomaly Treatment:
- Automatically selects optimal historical window
- Retrains algorithms when patterns shift
- No manual threshold tuning required

## Webhook Integration

### Slack Notifications

Configure in Soda Cloud UI:
1. Navigate to **Integrations** > **Webhooks**
2. Add Slack incoming webhook URL
3. Select events: check alerts, incidents, agreements

Webhook payload includes scan results, check details, and dataset info.

### Jira Issue Creation

Route incidents to Jira automatically:
1. Configure webhook URL pointing to Jira's REST API
2. Map Soda incident fields to Jira issue fields
3. Auto-create issues on fail-level check results

### PagerDuty Alerts

Send critical data quality failures to PagerDuty:
1. Use PagerDuty Events API v2 integration URL
2. Configure in Soda Cloud webhook settings
3. Map fail-level alerts to PagerDuty incidents

### Webhook Requirements

| Requirement | Value |
|-------------|-------|
| Protocol | HTTPS (TLS 1.2+) |
| Response time | < 10 seconds |
| Response code | HTTP 200-400 |
| Events | Check alerts, incident updates, agreement changes |

## Incident Management

### Incident Lifecycle

```
Check Fails --> Incident Created --> Assigned --> Investigated --> Resolved
                     |                                    |
                     v                                    v
              Webhook Fires                      Root Cause Logged
         (Slack/Jira/PagerDuty)
```

In Soda Cloud:
- Incidents auto-created when fail thresholds are breached
- Assign incidents to team members
- Add notes and root cause analysis
- Track mean time to resolution (MTTR)

## SLA Monitoring Pattern

```yaml
# Freshness SLAs per dataset
checks for orders:
  - freshness(created_at):
      warn: when > 1h
      fail: when > 4h
      name: "Orders Freshness SLA (4h)"

checks for payments:
  - freshness(processed_at):
      warn: when > 30m
      fail: when > 2h
      name: "Payments Freshness SLA (2h)"

# Completeness SLAs
checks for customers:
  - missing_percent(email):
      warn: when > 1%
      fail: when > 5%
      name: "Customer Email Completeness SLA (95%)"
```

## Scheduled Scans

### Cron-Based (Soda Cloud)

Configure scan schedules in Soda Cloud UI for regular monitoring without manual triggers.

### Orchestrator-Based

```python
# Dagster: schedule Soda scans as assets
from dagster import ScheduleDefinition, define_asset_job

soda_job = define_asset_job("soda_scan_job", selection="orders_quality_check")
soda_schedule = ScheduleDefinition(
    job=soda_job,
    cron_schedule="0 */4 * * *",  # every 4 hours
)
```

## Best Practices

| Practice | Rationale |
|----------|-----------|
| Always set both warn and fail | Catch issues before they become critical |
| Name all production checks | Readable alerts and dashboards |
| Use freshness checks on every table | Detect stale data early |
| Route fail alerts to PagerDuty | Critical issues get immediate attention |
| Route warn alerts to Slack | Team awareness without paging |
| Review anomaly detection weekly | Ensure ML baselines are accurate |

## See Also

- [Checks](../concepts/checks.md)
- [Soda Cloud](../concepts/soda-cloud.md)
- [CI/CD Integration](../patterns/ci-cd-integration.md)
