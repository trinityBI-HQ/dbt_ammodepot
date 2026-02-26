# CloudWatch Cost Optimization

> **Purpose**: Strategies to reduce CloudWatch spending on logs, metrics, dashboards, and alarms
> **MCP Validated**: 2026-02-19

## When to Use

- CloudWatch bill exceeds budget or expectations
- Log storage costs growing due to missing retention policies
- Custom metric count is high from unbounded dimensions
- Preparing for cost review or FinOps audit

## Cost Breakdown

| Component | Typical Share | Key Cost Drivers |
|-----------|---------------|------------------|
| **Logs ingestion** | 38% | Volume, verbose logging, debug logs in prod |
| **Custom metrics** | 31% | High cardinality, unused metrics |
| **Log storage** | 15% | No retention policy (infinite by default) |
| **Dashboards** | 5% | >3 dashboards at $3/month each |
| **Alarms** | 5% | Standard ($0.10/mo), high-res ($0.30/mo), anomaly ($3/mo) |
| **Synthetics** | 3% | Frequent canary runs |
| **Logs Insights** | 3% | Large queries scanning TBs of data |

## Free Tier (Always Free)

| Resource | Free Amount |
|----------|-------------|
| Custom metrics | 10 |
| Alarms (standard) | 10 |
| Dashboards | 3 |
| Log ingestion | 5 GB/month |
| Log storage | 5 GB/month |
| API requests | 1M GetMetricData, 1M other |
| Synthetics | 100 canary runs/month |
| Contributor Insights | 1 rule, 1M matched events |

## Strategy 1: Log Retention Policies

The single highest-impact optimization. Logs with no retention grow indefinitely.

```python
import boto3

logs = boto3.client('logs')

# Audit all log groups without retention
paginator = logs.get_paginator('describe_log_groups')
for page in paginator.paginate():
    for group in page['logGroups']:
        if 'retentionInDays' not in group:
            name = group['logGroupName']
            size_gb = group.get('storedBytes', 0) / (1024**3)
            print(f"NO RETENTION: {name} ({size_gb:.2f} GB)")

            # Set 30-day retention
            logs.put_retention_policy(
                logGroupName=name,
                retentionInDays=30
            )
```

```bash
# CLI: Set retention on all log groups without a policy
aws logs describe-log-groups --query 'logGroups[?!retentionInDays].logGroupName' --output text | \
  tr '\t' '\n' | \
  xargs -I {} aws logs put-retention-policy --log-group-name {} --retention-in-days 30
```

### Recommended Retention by Use Case

| Use Case | Retention | Rationale |
|----------|-----------|-----------|
| Development | 7 days | Short-lived debugging |
| Production (non-critical) | 30 days | Covers most incident windows |
| Production (critical) | 90 days | Regulatory or deep debugging |
| Compliance/audit | 1-10 years | Export to S3 instead for cost |

## Strategy 2: Reduce Log Volume

```python
import logging
import os

# Set log level via environment variable
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.getLogger().setLevel(getattr(logging, log_level))

# In production: INFO level only
# In development: DEBUG level
# Never: log full request/response bodies in production
```

**High-impact actions:**
- Remove debug logging from production Lambda functions
- Avoid logging full request/response payloads (log IDs and status instead)
- Use structured JSON logging (smaller than unstructured text)
- Filter subscription filters to only forward relevant logs

## Strategy 3: Custom Metric Optimization

```python
# BAD: Unique dimension values create unlimited metrics
cw.put_metric_data(
    Namespace='MyApp',
    MetricData=[{
        'MetricName': 'RequestLatency',
        'Dimensions': [{'Name': 'RequestId', 'Value': unique_id}],  # Millions!
        'Value': 150
    }]
)

# GOOD: Bounded dimension values
cw.put_metric_data(
    Namespace='MyApp',
    MetricData=[{
        'MetricName': 'RequestLatency',
        'Dimensions': [
            {'Name': 'Endpoint', 'Value': '/api/orders'},   # Bounded
            {'Name': 'StatusCode', 'Value': '200'}           # Bounded
        ],
        'Value': 150
    }]
)
```

**Rules:**
- Each unique dimension combination = 1 metric = $0.30/month
- 10 endpoints x 5 status codes = 50 metrics = $15/month
- Add a request ID dimension = potentially millions of metrics

## Strategy 4: Use EMF Instead of PutMetricData

```text
PutMetricData:   $0.30/metric/month + API call costs
EMF (via logs):  $0.50/GB log ingestion only (shared with existing logs)
```

For Lambda functions, EMF is almost always cheaper because log ingestion is already happening.

## Strategy 5: Dashboard Consolidation

```text
Before: 15 dashboards x $3/month = $45/month
After:  3 dashboards (free tier) + 2 critical = $6/month
```

- Consolidate per-function dashboards into per-service dashboards
- Use CloudWatch Contributor Insights for top-N analysis instead of many widgets
- Remove dashboards that nobody actively monitors

## Strategy 6: Alarm Optimization

| Alarm Type | Monthly Cost | Optimization |
|------------|-------------|--------------|
| Standard metric | $0.10 | Use composite alarms to reduce count |
| High-resolution | $0.30 | Only for truly critical, sub-minute alerting |
| Anomaly detection | $3.00 | Reserve for high-value, unpredictable metrics |

## Strategy 7: Export Infrequent Logs to S3

```text
CloudWatch Logs storage: $0.03/GB/month
S3 Standard:             $0.023/GB/month
S3 Intelligent-Tiering:  $0.023/GB/month (auto-tiers to $0.004)
S3 Glacier:              $0.004/GB/month
```

For compliance logs older than 30 days, export to S3 and query with Athena on demand.

## Terraform: Enforce Retention

```hcl
resource "aws_cloudwatch_log_group" "service" {
  name              = "/app/${var.service}/${var.env}"
  retention_in_days = var.env == "prod" ? 30 : 7

  tags = {
    CostCenter = var.cost_center
  }
}
```

## Strategy 8: Cross-Account Log Centralization (Sep 2025)

Use native cross-account log copy instead of per-account Firehose pipelines. The first cross-account log copy is free (no additional ingestion charge), reducing cost for multi-account organizations.

## Cost Monitoring

Set a billing alarm on `AWS/Billing` namespace, `EstimatedCharges` metric with dimension `ServiceName=AmazonCloudWatch` to alert when CloudWatch spend exceeds your budget threshold.

## See Also

- [Logs Concept](../concepts/logs.md) - Retention and pricing details
- [Metrics Concept](../concepts/metrics.md) - Metric resolution and limits
- [Custom Metrics](custom-metrics.md) - Efficient metric publishing
- [Log Aggregation](log-aggregation.md) - S3 export patterns
