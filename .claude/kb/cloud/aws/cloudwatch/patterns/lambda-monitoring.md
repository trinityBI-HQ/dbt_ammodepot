# Lambda Monitoring with CloudWatch

> **Purpose**: Comprehensive observability for AWS Lambda functions using CloudWatch metrics, logs, and insights
> **MCP Validated**: 2026-02-19

## When to Use

- Monitoring Lambda function performance, errors, and cold starts
- Setting up alerting for Lambda-based applications
- Debugging production issues with structured logging
- Tracking Lambda cost efficiency via duration and memory metrics

## Built-in Lambda Metrics

| Metric | What It Tells You | Alarm On |
|--------|-------------------|----------|
| `Invocations` | Request volume | Unexpected drops to 0 |
| `Errors` | Unhandled exceptions | Any errors in production |
| `Duration` | Execution time (ms) | P99 approaching timeout |
| `Throttles` | Concurrency limit hits | Any throttles |
| `ConcurrentExecutions` | Active instances | Near account limit |
| `IteratorAge` | Stream processing lag | Growing lag (Kinesis/DynamoDB) |

## Implementation: Structured Logging

```python
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    # Structured JSON logging for Logs Insights queries
    logger.info(json.dumps({
        "event": "request_received",
        "function_name": context.function_name,
        "request_id": context.aws_request_id,
        "memory_limit_mb": context.memory_limit_in_mb,
        "remaining_time_ms": context.get_remaining_time_in_millis()
    }))

    try:
        result = process(event)
        logger.info(json.dumps({
            "event": "request_completed",
            "request_id": context.aws_request_id,
            "status": "success",
            "items_processed": len(result)
        }))
        return result
    except Exception as e:
        logger.error(json.dumps({
            "event": "request_failed",
            "request_id": context.aws_request_id,
            "error_type": type(e).__name__,
            "error_message": str(e)
        }))
        raise
```

## Implementation: Lambda Powertools Logging

```python
from aws_lambda_powertools import Logger, Metrics, Tracer
from aws_lambda_powertools.metrics import MetricUnit

logger = Logger(service="payment-api")
metrics = Metrics(namespace="PaymentService")
tracer = Tracer(service="payment-api")

@logger.inject_lambda_context(log_event=True)
@metrics.log_metrics(capture_cold_start_metric=True)
@tracer.capture_lambda_handler
def handler(event, context):
    metrics.add_metric(name="OrdersProcessed", unit=MetricUnit.Count, value=1)
    metrics.add_dimension(name="Environment", value=os.environ.get("ENV", "dev"))

    logger.info("Processing order", extra={"order_id": event.get("order_id")})
    return {"statusCode": 200}
```

## Implementation: Alarms

```python
import boto3

cw = boto3.client('cloudwatch')

# Error rate alarm
cw.put_metric_alarm(
    AlarmName='Lambda-MyFunc-Errors',
    Namespace='AWS/Lambda',
    MetricName='Errors',
    Dimensions=[{'Name': 'FunctionName', 'Value': 'my-func'}],
    Statistic='Sum',
    Period=300,
    EvaluationPeriods=2,
    DatapointsToAlarm=2,
    Threshold=1,
    ComparisonOperator='GreaterThanOrEqualToThreshold',
    TreatMissingData='notBreaching',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:lambda-alerts']
)

# Duration alarm (approaching timeout)
cw.put_metric_alarm(
    AlarmName='Lambda-MyFunc-HighDuration',
    Namespace='AWS/Lambda',
    MetricName='Duration',
    Dimensions=[{'Name': 'FunctionName', 'Value': 'my-func'}],
    ExtendedStatistic='p99',
    Period=300,
    EvaluationPeriods=3,
    Threshold=25000,  # 25s of 30s timeout
    ComparisonOperator='GreaterThanThreshold',
    TreatMissingData='notBreaching',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:lambda-alerts']
)

# Throttle alarm
cw.put_metric_alarm(
    AlarmName='Lambda-MyFunc-Throttles',
    Namespace='AWS/Lambda',
    MetricName='Throttles',
    Dimensions=[{'Name': 'FunctionName', 'Value': 'my-func'}],
    Statistic='Sum',
    Period=60,
    EvaluationPeriods=1,
    Threshold=0,
    ComparisonOperator='GreaterThanThreshold',
    TreatMissingData='notBreaching',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:lambda-alerts']
)
```

## Lambda Insights (Enhanced Monitoring)

Enable Lambda Insights for system-level metrics (CPU, memory, disk, network) using the Embedded Metric Format (EMF).

```yaml
# SAM template
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Layers:
        - !Sub "arn:aws:lambda:${AWS::Region}:580247275435:layer:LambdaInsightsExtension:49"
      Policies:
        - CloudWatchLambdaInsightsExecutionRolePolicy
```

Lambda Insights publishes to the `LambdaInsights` namespace:
- `cpu_total_time`, `memory_utilization`, `rx_bytes`, `tx_bytes`
- `init_duration` (cold start), `tmp_used`, `tmp_max`

## Useful Logs Insights Queries

```text
# Cold start frequency and duration
filter @type = "REPORT"
| parse @message "Init Duration: * ms" as initDuration
| stats count(*) as coldStarts,
        avg(initDuration) as avgInit,
        max(initDuration) as maxInit
  by bin(1h)

# Memory utilization
filter @type = "REPORT"
| parse @message "Max Memory Used: * MB" as memUsed
| parse @message "Memory Size: * MB" as memSize
| stats avg(memUsed/memSize * 100) as avgUtilPct by bin(1h)
```

## Terraform Example

```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = var.function_name
  }
}
```

## See Also

- [Metrics](../concepts/metrics.md) -- [Alarms](../concepts/alarms.md) -- [Alerting](alerting-notifications.md) -- [Custom Metrics](custom-metrics.md)
