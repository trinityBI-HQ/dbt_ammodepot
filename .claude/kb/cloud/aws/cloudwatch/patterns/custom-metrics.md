# Publishing Custom Metrics

> **Purpose**: Instrument applications with custom CloudWatch metrics using SDK, EMF, StatsD, and CloudWatch Agent
> **MCP Validated**: 2026-02-19

## When to Use

- Tracking business KPIs (orders processed, revenue, conversion rates)
- Monitoring application-specific metrics not provided by AWS
- Publishing high-resolution metrics for real-time alerting
- Instrumenting Lambda functions with minimal overhead

## Approaches Comparison

| Method | Best For | Latency | Cost | Cardinality |
|--------|----------|---------|------|-------------|
| **PutMetricData API** | Simple, low-volume | Real-time | $0.30/metric/mo | Low |
| **Embedded Metric Format (EMF)** | Lambda, ECS | Via logs | Log ingestion only | Medium |
| **CloudWatch Agent + StatsD** | EC2, ECS, on-prem | Configurable | $0.30/metric/mo | Low |
| **Powertools Metrics** | Lambda (Python) | Via EMF | Log ingestion only | Medium |

## Implementation: PutMetricData API

```python
import boto3
from datetime import datetime

cw = boto3.client('cloudwatch')

# Single metric
cw.put_metric_data(
    Namespace='MyApp/Production',
    MetricData=[{
        'MetricName': 'OrdersProcessed',
        'Value': 1,
        'Unit': 'Count',
        'Timestamp': datetime.utcnow(),
        'Dimensions': [
            {'Name': 'Service', 'Value': 'checkout'},
            {'Name': 'Environment', 'Value': 'prod'}
        ]
    }]
)

# Batch with statistics (aggregate before sending)
cw.put_metric_data(
    Namespace='MyApp/Production',
    MetricData=[{
        'MetricName': 'ProcessingTime',
        'StatisticValues': {
            'SampleCount': 100,
            'Sum': 5000,
            'Minimum': 10,
            'Maximum': 200
        },
        'Unit': 'Milliseconds',
        'Dimensions': [
            {'Name': 'Service', 'Value': 'checkout'}
        ]
    }]
)

# High-resolution metric (1-second granularity)
cw.put_metric_data(
    Namespace='MyApp/Production',
    MetricData=[{
        'MetricName': 'ActiveConnections',
        'Value': 42,
        'StorageResolution': 1,  # 1 = high-res, 60 = standard
        'Unit': 'Count'
    }]
)
```

## Implementation: Embedded Metric Format (EMF)

EMF publishes metrics through CloudWatch Logs, avoiding direct API calls. Ideal for Lambda.

```python
import json
import sys

def emit_emf_metric(namespace, metric_name, value, unit="Count", dimensions=None):
    """Publish a metric using Embedded Metric Format via stdout."""
    emf_log = {
        "_aws": {
            "Timestamp": int(__import__('time').time() * 1000),
            "CloudWatchMetrics": [{
                "Namespace": namespace,
                "Dimensions": [list(dimensions.keys())] if dimensions else [[]],
                "Metrics": [{"Name": metric_name, "Unit": unit}]
            }]
        },
        metric_name: value
    }
    if dimensions:
        emf_log.update(dimensions)

    print(json.dumps(emf_log))
    sys.stdout.flush()

# Usage in Lambda
def handler(event, context):
    emit_emf_metric(
        namespace="MyApp/Production",
        metric_name="OrderValue",
        value=99.99,
        unit="None",
        dimensions={"Service": "checkout", "Region": "us-east-1"}
    )
```

## Implementation: AWS Lambda Powertools Metrics

```python
from aws_lambda_powertools import Metrics
from aws_lambda_powertools.metrics import MetricUnit

metrics = Metrics(namespace="MyApp/Production", service="checkout")

@metrics.log_metrics(capture_cold_start_metric=True)
def handler(event, context):
    metrics.add_dimension(name="Environment", value="prod")

    # Single metric
    metrics.add_metric(name="OrdersProcessed", unit=MetricUnit.Count, value=1)

    # Multiple values for the same metric (aggregated)
    for item in event.get('items', []):
        metrics.add_metric(
            name="ItemValue",
            unit=MetricUnit.Count,
            value=item['price']
        )

    return {"statusCode": 200}
```

## Implementation: CloudWatch Agent (StatsD)

Configure the CloudWatch Agent with `statsd` collector on port 8125:

```python
import statsd
c = statsd.StatsClient('localhost', 8125, prefix='myapp')
c.incr('orders.processed')
c.timing('request.duration', 250)
c.gauge('queue.depth', 42)
```

## Terraform: Custom Metric Alarm

```hcl
resource "aws_cloudwatch_metric_alarm" "high_order_failures" {
  alarm_name          = "high-order-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "OrderFailures"
  namespace           = "MyApp/Production"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    Service     = "checkout"
    Environment = "prod"
  }
}
```

## Best Practices

| Practice | Why |
|----------|-----|
| Use bounded dimensions | Unbounded dimensions (request IDs) create millions of metrics |
| Batch PutMetricData calls | Max 1,000 values per call; reduces API cost |
| Prefer EMF in Lambda | Avoids PutMetricData API call overhead and cost |
| Use StatisticValues for aggregation | Pre-aggregate on client to reduce data points |
| Choose standard resolution unless needed | High-res costs more and retains less |
| Define a naming convention | `{App}/{Env}/{Service}` namespace pattern |

**Limits**: 1,000 values per PutMetricData call, 100 metrics per EMF log, 30 dimensions per metric.

## Tag-Based Metric Queries (Sep 2025)

Use AWS resource tags to dynamically scope metric queries and alarms instead of hardcoded dimension values. Ideal for fleet-wide monitoring where resources change frequently.

```text
# Metrics Insights query using tags
SELECT AVG(Duration) FROM "AWS/Lambda"
WHERE aws:lambda:function:tag/Team = 'payments'
GROUP BY FunctionName
```

Tag-based telemetry works with alarms, dashboards, and Metrics Insights queries. Resources matching tag filters are included automatically.

**See Also**: [Metrics Concept](../concepts/metrics.md) -- [Lambda Monitoring](lambda-monitoring.md) -- [Cost Optimization](cost-optimization.md)
