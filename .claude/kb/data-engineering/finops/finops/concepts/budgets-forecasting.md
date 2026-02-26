# Budgets and Forecasting

> **Purpose**: Setting cloud budgets, forecasting spend, and detecting cost anomalies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Budgets and forecasting transform reactive cost management into proactive financial planning. By setting budget thresholds, building forecast models, and detecting anomalies, data engineering teams can prevent bill shock, plan capacity, and justify infrastructure investments with data-driven projections.

## Budget Types

### Cloud Provider Budgets

| Provider | Budget Tool | Alert Channels | Granularity |
|----------|-------------|---------------|-------------|
| AWS | AWS Budgets | SNS, Email, Chatbot | Account, service, tag |
| GCP | GCP Budget Alerts | Pub/Sub, Email | Project, service, label |
| Snowflake | Resource Monitors | Email, UI notification | Warehouse, account |
| Databricks | Budget Policies | Email, webhook | Workspace, cluster |

### AWS Budget Example

```json
{
  "BudgetName": "data-engineering-monthly",
  "BudgetLimit": {"Amount": "15000", "Unit": "USD"},
  "BudgetType": "COST",
  "CostFilters": {"TagKeyValue": ["user:team$data-engineering"]},
  "NotificationsWithSubscribers": [
    {"Notification": {"NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN", "Threshold": 80},
     "Subscribers": [{"Address": "data-team@company.com", "SubscriptionType": "EMAIL"}]},
    {"Notification": {"NotificationType": "FORECASTED", "ComparisonOperator": "GREATER_THAN", "Threshold": 100},
     "Subscribers": [{"Address": "data-team@company.com", "SubscriptionType": "EMAIL"}]}
  ]
}
```

### Snowflake Resource Monitor

```sql
-- Create a resource monitor with alerts and auto-suspend
CREATE RESOURCE MONITOR data_eng_monitor
  WITH CREDIT_QUOTA = 5000
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

-- Apply to specific warehouses
ALTER WAREHOUSE DE_ETL_MEDIUM SET RESOURCE_MONITOR = data_eng_monitor;
ALTER WAREHOUSE DE_TRANSFORM_LARGE SET RESOURCE_MONITOR = data_eng_monitor;
```

## Forecasting Models

### Simple Approaches

| Method | Best For | Accuracy |
|--------|----------|----------|
| **Trailing average** | Stable workloads | +/- 20% |
| **Linear trend** | Steady growth | +/- 15% |
| **Seasonal decomposition** | Workloads with patterns | +/- 10% |
| **Driver-based** | When volume metrics exist | +/- 5-10% |

### Driver-Based Forecasting (Recommended)

```text
Formula:
  Forecast = (Expected data volume) x (Cost per GB) + (Expected query count) x (Cost per query) + Fixed costs

Example:
  Expected data volume: 50 TB/month (growing 10%/month)
  Cost per GB processed: $0.05
  Expected queries: 10,000/month
  Cost per query: $0.08
  Fixed costs (storage, networking): $2,000/month

  Month 1: (50,000 x $0.05) + (10,000 x $0.08) + $2,000 = $5,300
  Month 2: (55,000 x $0.05) + (11,000 x $0.08) + $2,000 = $5,830
  Month 3: (60,500 x $0.05) + (12,100 x $0.08) + $2,000 = $5,993
```

## Anomaly Detection

### What to Monitor

| Signal | Threshold | Likely Cause |
|--------|-----------|--------------|
| Daily spend > 2x rolling average | Alert | Runaway query, cluster misconfiguration |
| Storage growth > 3x normal | Investigate | Duplicated data, failed cleanup |
| Query count spike > 5x | Alert | Dashboard loop, misconfigured refresh |
| New untagged resources | Enforce | Manual provisioning outside IaC |

### AWS Cost Anomaly Detection

```text
AWS Cost Anomaly Detection:
  - Automatically detects unusual spend patterns
  - Uses ML to learn normal spending behavior
  - Configurable alert thresholds (% or absolute $)
  - Integrates with SNS for Slack/email notifications

Setup: AWS Console > Cost Management > Cost Anomaly Detection > Create monitor
  - Monitor type: AWS service (for broad) or Cost category (for specific)
  - Alert: Individual anomalies > $100 or 20% above expected
```

## Budget Review Cadence

| Frequency | Audience | Focus |
|-----------|----------|-------|
| **Daily** | On-call/automated | Anomaly alerts, threshold breaches |
| **Weekly** | Data eng leads | Burn rate, top cost drivers |
| **Monthly** | Eng + Finance | Budget vs actual, forecast update |
| **Quarterly** | Leadership | Commitment renewals, capacity planning |

## Common Mistakes

### Wrong

```text
- Set budgets once and never review them
- Use only total spend alerts (miss per-service spikes)
- Forecast using last month only (ignores trends)
```

### Correct

```text
- Review and adjust budgets monthly based on actuals
- Set tiered alerts (80%, 90%, 100%) per team/service
- Use driver-based forecasting tied to data volume growth
```

## Related

- [Framework](framework.md) -- Budgeting is a core Inform capability
- [Governance](governance.md) -- Budgets feed into governance policies
- [Unit Economics](unit-economics.md) -- Unit costs improve forecast accuracy
