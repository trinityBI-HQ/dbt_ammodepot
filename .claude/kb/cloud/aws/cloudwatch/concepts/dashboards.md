# CloudWatch Dashboards

> **Purpose**: Customizable visualizations for metrics, logs, and alarms across accounts
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Dashboards provide customizable home pages in the CloudWatch console for monitoring resources in a single view. Dashboards support widgets for metrics, logs, alarms, text, and custom content. Cross-account and cross-region dashboards enable centralized monitoring across your AWS organization.

## Widget Types

| Widget | Purpose | Data Source |
|--------|---------|-------------|
| **Line** | Time-series trends | Metrics |
| **Stacked area** | Cumulative trends | Metrics |
| **Number** | Single current value | Metrics |
| **Bar** | Comparison across dimensions | Metrics |
| **Pie** | Proportional distribution | Metrics |
| **Gauge** | Value against a range | Metrics |
| **Log table** | Recent log entries | Logs Insights query |
| **Alarm status** | Alarm state overview | Alarms |
| **Text** | Markdown documentation | Static content |
| **Custom** | Lambda-backed dynamic content | Lambda function |

## Dashboard JSON Structure

Each widget specifies `type`, position (`x`, `y`), size (`width`, `height`), and `properties`. Types: `metric`, `log`, `alarm`, `text`, `custom`.

```json
{
  "widgets": [{
    "type": "metric",
    "x": 0, "y": 0, "width": 12, "height": 6,
    "properties": {
      "metrics": [
        ["AWS/Lambda", "Invocations", "FunctionName", "my-func", {"stat": "Sum", "period": 300}],
        [".", "Errors", ".", ".", {"stat": "Sum", "period": 300, "color": "#d62728"}]
      ],
      "view": "timeSeries", "region": "us-east-1",
      "title": "Lambda Invocations & Errors"
    }
  }]
}
```

## Cross-Account Dashboards

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Errors", "FunctionName", "api-handler", {
            "accountId": "111111111111"
          }],
          ["AWS/Lambda", "Errors", "FunctionName", "api-handler", {
            "accountId": "222222222222"
          }]
        ],
        "title": "Errors Across Accounts"
      }
    }
  ]
}
```

Requires CloudWatch cross-account observability setup with a monitoring account and source accounts linked via the Observability Access Manager (OAM).

## Create Dashboard

```bash
# CLI
aws cloudwatch put-dashboard \
  --dashboard-name "Production-Overview" \
  --dashboard-body file://dashboard.json

# boto3
import boto3, json
client = boto3.client('cloudwatch')
client.put_dashboard(DashboardName='Production-Overview',
                     DashboardBody=json.dumps(dashboard_body))
```

## Annotations

Add `horizontal` (threshold lines with `fill: "above"/"below"`) or `vertical` (deployment markers with ISO timestamps) annotations to any metric widget.

## Pricing

| Item | Cost |
|------|------|
| First 3 dashboards | Free |
| Additional dashboards | $3.00/month each |
| API calls | Included |

## Dynamic Tag-Based Dashboards (Sep 2025)

Dashboard widgets can now use AWS resource tags to dynamically scope metrics. Widgets automatically include new resources matching tag filters without manual updates.

```json
{
  "type": "metric",
  "properties": {
    "metrics": [
      ["AWS/Lambda", "Errors", {
        "stat": "Sum",
        "tagFilters": [
          { "Key": "Team", "Value": ["payments"] }
        ]
      }]
    ],
    "title": "Errors - Payments Team (auto-discovered)"
  }
}
```

Benefits:
- New Lambda functions tagged `Team=payments` appear automatically
- No dashboard updates needed when resources are added or removed
- Combine with cross-account OAM for org-wide tag-based views

## Common Mistakes

### Wrong

Creating dozens of dashboards with overlapping metrics, hardcoding resource names that go stale.

### Correct

Create focused dashboards by service or team. Use tag-based widgets for dynamic resource discovery. Set clear ownership and include alarm widgets for actionable status at a glance.

## Related

- [Metrics](metrics.md) - Data visualized in dashboards
- [Alarms](alarms.md) - Alarm widgets on dashboards
- [Cost Optimization](../patterns/cost-optimization.md) - Dashboard cost management
