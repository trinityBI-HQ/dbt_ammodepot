# Cost Monitoring and Alerting

> **Purpose**: Build dashboards, alerts, and anomaly detection for data infrastructure costs
> **MCP Validated**: 2026-02-19

## When to Use

- No visibility into daily/weekly cost trends
- Cost spikes discovered only at end of month
- Teams do not know which pipelines cost the most
- Budget breaches happen without warning
- Finance requires regular cost reporting

## Monitoring Architecture

```
Data Sources              Aggregation              Visualization
+------------------+     +------------------+     +------------------+
| AWS Cost Explorer |     |                  |     |                  |
| GCP Billing Export| --> | Cost Database    | --> | Dashboard        |
| Snowflake Usage  |     | (BigQuery, S3,   |     | (Looker, Grafana,|
| Databricks System|     |  Snowflake)      |     |  Tableau, custom)|
+------------------+     +------------------+     +------------------+
                                |
                          +-----+-----+
                          |  Alerting |
                          | (PagerDuty|
                          |  Slack,   |
                          |  Email)   |
                          +-----------+
```

## AWS Cost Monitoring

### Cost Explorer Queries

```python
import boto3
from datetime import datetime, timedelta

client = boto3.client('ce')

# Get daily costs by service for data engineering
response = client.get_cost_and_usage(
    TimePeriod={
        'Start': (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'),
        'End': datetime.now().strftime('%Y-%m-%d')
    },
    Granularity='DAILY',
    Metrics=['UnblendedCost'],
    Filter={
        'Tags': {
            'Key': 'team',
            'Values': ['data-engineering']
        }
    },
    GroupBy=[
        {'Type': 'DIMENSION', 'Key': 'SERVICE'}
    ]
)

for result in response['ResultsByTime']:
    date = result['TimePeriod']['Start']
    for group in result['Groups']:
        service = group['Keys'][0]
        cost = float(group['Metrics']['UnblendedCost']['Amount'])
        if cost > 0:
            print(f"{date} | {service}: ${cost:.2f}")
```

## Snowflake Cost Monitoring

```sql
-- Daily credit consumption by warehouse (30-day trend)
SELECT
    DATE_TRUNC('day', start_time) AS usage_date,
    warehouse_name,
    SUM(credits_used) AS daily_credits,
    SUM(credits_used) * 3.00 AS estimated_cost_usd
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY usage_date, warehouse_name
ORDER BY usage_date DESC, daily_credits DESC;

-- Top expensive queries (last 7 days)
SELECT
    query_id, user_name, warehouse_name, warehouse_size,
    execution_time / 1000 AS seconds,
    bytes_scanned / POWER(1024, 3) AS gb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY execution_time DESC
LIMIT 25;
```

## Databricks Cost Monitoring

### System Tables for Cost Analysis

```sql
-- Daily DBU consumption by workspace and cluster
SELECT
    DATE_TRUNC('day', usage_date) AS day,
    workspace_id,
    sku_name,
    usage_metadata.cluster_id,
    SUM(usage_quantity) AS total_dbus
FROM system.billing.usage
WHERE usage_date >= CURRENT_DATE() - INTERVAL 30 DAY
GROUP BY day, workspace_id, sku_name, usage_metadata.cluster_id
ORDER BY total_dbus DESC;

-- Identify all-purpose clusters running production jobs
SELECT
    usage_metadata.cluster_id,
    sku_name,
    SUM(usage_quantity) AS total_dbus,
    SUM(usage_quantity) * 0.55 AS estimated_cost_usd  -- adjust rate
FROM system.billing.usage
WHERE sku_name LIKE '%ALL_PURPOSE%'
    AND usage_date >= CURRENT_DATE() - INTERVAL 7 DAY
GROUP BY usage_metadata.cluster_id, sku_name
ORDER BY total_dbus DESC;
```

## Alert Configuration

### Alert Thresholds

| Alert | Threshold | Channel | Action |
|-------|-----------|---------|--------|
| Daily spend > 2x average | 200% of 30-day avg | Slack + Email | Investigate immediately |
| Weekly budget > 80% | 80% of weekly budget | Slack | Review top cost drivers |
| Untagged resource created | Any | Slack | Enforce tagging |
| Warehouse idle > 24h | 24 hours no queries | Email | Suspend or review |
| Storage growth > 3x normal | 300% of avg daily growth | Email | Check for data duplication |
| Query cost > $50 | Single query | Slack | Optimize query |

## Dashboard Panels

| Panel | Visualization | Refresh |
|-------|--------------|---------|
| Total daily spend (trend) | Line chart, 30-day | Daily |
| Spend by team/project | Stacked bar | Daily |
| Top 10 pipelines by cost | Horizontal bar | Weekly |
| Budget burn rate | Gauge (% of monthly budget) | Daily |
| Cost per pipeline run (trend) | Line chart | Daily |
| Storage by tier | Donut chart | Weekly |
| Anomaly timeline | Scatter plot with threshold | Real-time |
| Commitment utilization | Gauge (% of purchased) | Weekly |

## See Also

- [Budgets and Forecasting](../concepts/budgets-forecasting.md) -- Setting the budgets that drive alerts
- [Unit Economics](../concepts/unit-economics.md) -- Metrics to display on dashboards
- [Governance](../concepts/governance.md) -- Automated responses to cost alerts
