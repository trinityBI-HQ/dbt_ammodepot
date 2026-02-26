# CloudWatch Logs

> **Purpose**: Centralized log ingestion, storage, querying, and metric extraction
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Logs collects and stores log data from AWS services and applications. Logs are organized into log groups (per application/service) and log streams (per instance/container). Logs Insights provides a SQL-like query language for interactive analysis. Metric filters extract numeric values from log data to create CloudWatch metrics.

## Core Structure

```text
Log Group:  /aws/lambda/my-function     (retention, encryption, access)
  Log Stream: 2026/02/12/[$LATEST]abc123  (append-only, per-instance)
    Log Events: { timestamp, message }     (max 256 KB per event)
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Log Groups** | Logical container; set retention, encryption, access per group |
| **Log Streams** | Sequence of events from one source (auto-created by Lambda, ECS) |
| **Metric Filters** | Pattern matching to extract metrics from log text |
| **Subscription Filters** | Stream logs in real-time to Lambda, Kinesis, or Firehose |
| **Logs Insights** | Interactive query engine for ad-hoc analysis |
| **Live Tail** | Real-time log viewing in the console |
| **Log Anomaly Detection** | ML-based detection of unusual log patterns |

## Logs Insights Query Syntax

```text
# Find errors in the last hour with context
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50

# Count errors by service
fields @message
| parse @message "service=* action=* status=*" as service, action, status
| filter status = "ERROR"
| stats count(*) as errorCount by service
| sort errorCount desc

# P99 latency from structured logs
fields @timestamp, duration
| filter ispresent(duration)
| stats pct(duration, 99) as p99,
        pct(duration, 95) as p95,
        avg(duration) as avg_duration
  by bin(5m)

# Lambda cold start analysis
filter @type = "REPORT"
| parse @message "Init Duration: * ms" as initDuration
| filter ispresent(initDuration)
| stats avg(initDuration), max(initDuration), count(*) by bin(1h)
```

## Metric Filters

Extract metrics from log patterns automatically.

```bash
# Create a metric filter for ERROR count
aws logs put-metric-filter \
  --log-group-name /aws/lambda/my-function \
  --filter-name ErrorCount \
  --filter-pattern "ERROR" \
  --metric-transformations \
    metricName=ErrorCount,metricNamespace=Custom/MyApp,metricValue=1,defaultValue=0
```

```python
import boto3

logs = boto3.client('logs')

logs.put_metric_filter(
    logGroupName='/aws/lambda/my-function',
    filterName='HighLatency',
    filterPattern='{ $.duration > 5000 }',
    metricTransformations=[{
        'metricName': 'HighLatencyCount',
        'metricNamespace': 'Custom/MyApp',
        'metricValue': '1',
        'defaultValue': 0
    }]
)
```

## Subscription Filters

Stream log data in real-time to downstream services.

| Destination | Use Case |
|-------------|----------|
| Lambda | Transform and forward logs |
| Kinesis Data Firehose | Deliver to S3, Redshift, or OpenSearch |
| Kinesis Data Streams | Custom real-time processing |

## Retention and Pricing

| Retention Period | Cost Impact |
|------------------|-------------|
| 1 day | Lowest storage cost |
| 7, 14, 30, 60, 90 days | Common production settings |
| 1, 2, 5, 10 years | Compliance requirements |
| Never expire (default) | Accumulates cost indefinitely |

**Pricing components**: ingestion ($0.50/GB), storage ($0.03/GB/month), Insights queries ($0.005/GB scanned).

## Cross-Account and Cross-Region Log Centralization (Sep 2025)

Copy logs from an entire AWS Organization or specific OUs to a central monitoring account across regions. No per-account subscription filter setup needed.

- **Org-wide or OU-scoped** log selection, **cross-region** capable
- **First copy free**: No additional ingestion charge for the first cross-account copy
- **Selective filtering**: Apply log group name patterns to copy only relevant logs

## Common Mistakes

### Wrong

```python
# No retention policy -- logs grow forever
logs.create_log_group(logGroupName='/app/prod')
```

### Correct

```python
# Always set retention when creating log groups
logs.create_log_group(logGroupName='/app/prod')
logs.put_retention_policy(
    logGroupName='/app/prod',
    retentionInDays=30
)
```

## Related

- [Metrics](metrics.md) - Metrics created from metric filters
- [Log Aggregation Pattern](../patterns/log-aggregation.md) - Centralized logging
- [Lambda Monitoring](../patterns/lambda-monitoring.md) - Lambda log patterns
