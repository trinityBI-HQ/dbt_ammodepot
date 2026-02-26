# CloudWatch Metrics

> **Purpose**: Time-series data points for monitoring AWS resources and custom applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Metrics are time-ordered data points published by AWS services or custom applications. Each metric belongs to a namespace, has a name, and is uniquely identified by up to 30 dimensions. Metrics support standard resolution (60-second periods) and high resolution (1-second periods).

## Core Structure

```text
Namespace:  AWS/Lambda
MetricName: Duration
Dimensions: FunctionName=my-func, Resource=my-func:LIVE
Datapoint:  { Timestamp, Value, Unit }
```

## Key Terminology

| Term | Description |
|------|-------------|
| **Namespace** | Container for metrics (e.g., `AWS/Lambda`, `Custom/MyApp`) |
| **Metric Name** | Identifier within a namespace (e.g., `Invocations`) |
| **Dimension** | Name-value pair that filters metrics (e.g., `FunctionName=X`) |
| **Period** | Aggregation interval in seconds (1, 5, 10, 30, 60, or multiples of 60) |
| **Statistic** | Aggregation function: Sum, Average, Min, Max, SampleCount |
| **Unit** | Measurement unit: Seconds, Bytes, Count, Percent, None |

## Resolution

| Type | Period | Retention | Cost |
|------|--------|-----------|------|
| Standard | 60 seconds | 15 days at 1-min, 63 days at 5-min, 15 months at 1-hour | Included for AWS metrics |
| High-Resolution | 1 second | 3 hours at 1-sec, then rolls up | $0.30/metric/month first 10K |

## Metric Math

Combine metrics using expressions for derived insights.

```python
import boto3

client = boto3.client('cloudwatch')

# Get metric data with math expressions
response = client.get_metric_data(
    MetricDataQueries=[
        {
            'Id': 'errors',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/Lambda',
                    'MetricName': 'Errors',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': 'my-func'}
                    ]
                },
                'Period': 300,
                'Stat': 'Sum'
            }
        },
        {
            'Id': 'invocations',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/Lambda',
                    'MetricName': 'Invocations',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': 'my-func'}
                    ]
                },
                'Period': 300,
                'Stat': 'Sum'
            }
        },
        {
            'Id': 'error_rate',
            'Expression': '100 * errors / invocations',
            'Label': 'Error Rate %'
        }
    ],
    StartTime='2026-02-12T00:00:00Z',
    EndTime='2026-02-12T12:00:00Z'
)
```

## Common Mistakes

### Wrong

```python
# Publishing with unique request IDs as dimensions (high cardinality)
client.put_metric_data(
    Namespace='MyApp',
    MetricData=[{
        'MetricName': 'Latency',
        'Dimensions': [{'Name': 'RequestId', 'Value': req_id}],  # BAD
        'Value': 150
    }]
)
```

### Correct

```python
# Use bounded dimensions (service, environment, endpoint)
client.put_metric_data(
    Namespace='MyApp',
    MetricData=[{
        'MetricName': 'Latency',
        'Dimensions': [
            {'Name': 'Service', 'Value': 'payment-api'},
            {'Name': 'Environment', 'Value': 'prod'}
        ],
        'Value': 150,
        'Unit': 'Milliseconds'
    }]
)
```

## Tag-Based Telemetry (Sep 2025)

Query and alarm on metrics using AWS resource tags instead of hardcoded dimension values. Dashboards and alarms automatically include new resources matching tag filters.

```text
Metric: AWS/Lambda > Errors | Tag Filter: aws:lambda:function:tag/Team = "payments"
```

- **Tag-based alarms**: Alarms scoped by resource tags (e.g., all functions in a team)
- **Tag-based queries**: Tags in Metrics Insights queries for dynamic grouping
- **Dynamic dashboards**: Widgets auto-update as tagged resources are added/removed

## Limits

| Resource | Default Limit |
|----------|--------------|
| Custom metrics per account | No hard limit (cost-based) |
| Dimensions per metric | 30 |
| `PutMetricData` values per call | 1,000 |
| Metric data points per `GetMetricData` | 100,800 |
| Metric math expressions per query | 500 |

## Related

- [Alarms](alarms.md) - Set thresholds on metrics
- [Custom Metrics Pattern](../patterns/custom-metrics.md) - Publishing custom metrics
- [Cost Optimization](../patterns/cost-optimization.md) - Reducing metric costs
