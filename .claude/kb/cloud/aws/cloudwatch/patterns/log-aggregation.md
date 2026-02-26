# Log Aggregation and Analysis

> **Purpose**: Centralized log collection, cross-account aggregation, and long-term storage patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Centralizing logs from multiple AWS services and accounts
- Exporting logs to S3 for cost-effective long-term storage
- Setting up real-time log processing pipelines
- Querying logs across services for incident investigation

## Architecture: Centralized Logging

```text
Account A: Lambda, ECS, EC2 ─┐
Account B: Lambda, Glue      ─┼─> Subscription Filters ─> Kinesis Firehose
Account C: API Gateway        ─┘         │                       │
                                         │                       v
                                    Real-time            S3 (long-term)
                                    Lambda processor     Athena queries
```

## Implementation: Subscription Filter to S3 via Firehose

```python
import boto3

logs = boto3.client('logs')

# Create subscription filter to send logs to Kinesis Firehose
logs.put_subscription_filter(
    logGroupName='/aws/lambda/my-function',
    filterName='AllLogs',
    filterPattern='',  # Empty = all logs
    destinationArn='arn:aws:firehose:us-east-1:123456789:deliverystream/logs-to-s3',
    roleArn='arn:aws:iam::123456789:role/CWLogsToFirehoseRole'
)
```

## Implementation: Cross-Account Log Sharing

```python
# In the DESTINATION (monitoring) account
logs = boto3.client('logs')

logs.put_destination(
    destinationName='CentralizedLogs',
    targetArn='arn:aws:firehose:us-east-1:111111111111:deliverystream/central-logs',
    roleArn='arn:aws:iam::111111111111:role/CWLogsDestinationRole'
)

# Set resource policy to allow source accounts
logs.put_destination_policy(
    destinationName='CentralizedLogs',
    accessPolicy=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"AWS": ["222222222222", "333333333333"]},
            "Action": "logs:PutSubscriptionFilter",
            "Resource": "arn:aws:logs:us-east-1:111111111111:destination:CentralizedLogs"
        }]
    })
)

# In each SOURCE account, create subscription filter to the destination
logs.put_subscription_filter(
    logGroupName='/aws/lambda/source-function',
    filterName='CrossAccountLogs',
    filterPattern='',
    destinationArn='arn:aws:logs:us-east-1:111111111111:destination:CentralizedLogs'
)
```

## Implementation: Export to S3 (Batch)

```python
import boto3
import time

logs = boto3.client('logs')

# One-time export of a log group to S3
task = logs.create_export_task(
    logGroupName='/aws/lambda/my-function',
    fromTime=int((time.time() - 86400) * 1000),  # Last 24 hours
    to=int(time.time() * 1000),
    destination='my-log-archive-bucket',
    destinationPrefix='cloudwatch-exports/lambda/my-function'
)

# Check export status
response = logs.describe_export_tasks(taskId=task['taskId'])
print(response['exportTasks'][0]['status']['code'])
```

## Implementation: Real-Time Processing with Lambda

```python
import base64
import gzip
import json

def handler(event, context):
    """Process CloudWatch Logs delivered via subscription filter."""
    payload = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(payload))

    for log_event in log_data['logEvents']:
        message = log_event['message']

        # Parse structured JSON logs
        try:
            parsed = json.loads(message)
            if parsed.get('level') == 'ERROR':
                # Forward to alerting system, store in DynamoDB, etc.
                process_error(parsed)
        except json.JSONDecodeError:
            pass  # Handle non-JSON logs
```

## Terraform: Log Group with Retention and Export

```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.service_name}/${var.environment}"
  retention_in_days = 30

  tags = {
    Service     = var.service_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_subscription_filter" "to_firehose" {
  name            = "${var.service_name}-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.app.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs.arn
  role_arn        = aws_iam_role.cw_to_firehose.arn
}
```

## Configuration

| Setting | Recommended | Description |
|---------|-------------|-------------|
| Log retention | 30 days | Balance cost vs debugging needs |
| S3 export format | gzip JSON | Queryable with Athena |
| Subscription filter pattern | `""` or `ERROR` | Empty for all, pattern for filtered |
| Firehose buffer interval | 60-300s | Lower = faster, higher = fewer S3 files |
| Firehose buffer size | 5-128 MB | Larger = fewer files, more latency |

## Log Format Best Practices

```python
# Structured JSON for easy querying
import json
import logging

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": "my-app",
            "environment": "prod"
        }
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)
```

## Implementation: Org-Wide Cross-Account Log Centralization (Sep 2025)

Native cross-account log copy eliminates per-account subscription filter setup. Copies logs from an entire Organization or OU to a central account, across regions. First copy is free (no additional ingestion charge).

Configure via CloudWatch console: **Settings > Cross-account log centralization**.

Key settings: Source (Organization ID or OU ID), source regions (all or specific), log group filter pattern (e.g., `/aws/lambda/*`), and destination log group in the central account. Requires OAM links between accounts.

**Compared to subscription filters**: No per-account setup, no Firehose required, no Lambda transformer. Configure once in the monitoring account.

## See Also

- [Logs Concept](../concepts/logs.md) - Log groups, streams, Insights syntax
- [Lambda Monitoring](lambda-monitoring.md) - Lambda-specific logging
- [Alerting Pattern](alerting-notifications.md) - Alert on log patterns
- [Cost Optimization](cost-optimization.md) - Reducing log costs
