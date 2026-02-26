# CloudWatch Events / EventBridge

> **Purpose**: Event-driven automation triggered by AWS resource state changes and schedules
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Events delivers a stream of system events describing changes to AWS resources. Amazon EventBridge is the evolution of CloudWatch Events, providing the same core functionality plus support for SaaS integrations, custom event buses, schema discovery, and cross-account event routing. New applications should use EventBridge; CloudWatch Events rules continue to work via the same underlying service.

## CloudWatch Events vs EventBridge

| Feature | CloudWatch Events | EventBridge |
|---------|-------------------|-------------|
| AWS events | Yes | Yes |
| SaaS integrations | No | Yes (Salesforce, Zendesk, etc.) |
| Custom event buses | No | Yes |
| Schema registry | No | Yes |
| Cross-account routing | Limited | Full support |
| Archive and replay | No | Yes |
| API | Same underlying API | Enhanced API |
| Status | Legacy (maintained) | Recommended |

## Event Structure

```json
{
  "version": "0",
  "id": "12345678-1234-1234-1234-123456789012",
  "detail-type": "EC2 Instance State-change Notification",
  "source": "aws.ec2",
  "account": "123456789012",
  "time": "2026-02-12T12:00:00Z",
  "region": "us-east-1",
  "resources": ["arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890"],
  "detail": {
    "instance-id": "i-1234567890",
    "state": "stopped"
  }
}
```

## Common Event Sources

| Source | Detail Type | Use Case |
|--------|-------------|----------|
| `aws.ec2` | EC2 Instance State-change | React to instance start/stop |
| `aws.s3` | Object Created | Trigger processing on upload |
| `aws.glue` | Glue Job State Change | Monitor ETL completion |
| `aws.codepipeline` | CodePipeline Action Execution | CI/CD notifications |
| `aws.health` | AWS Health Event | Service disruption alerts |
| `aws.cloudwatch` | CloudWatch Alarm State Change | Alarm-driven automation |
| `aws.ecs` | ECS Task State Change | Container lifecycle events |

## Creating Rules

### Schedule-Based Rule (Cron)

```python
import boto3

events = boto3.client('events')

events.put_rule(
    Name='DailyHealthCheck',
    ScheduleExpression='cron(0 8 * * ? *)',  # 8 AM UTC daily
    State='ENABLED',
    Description='Trigger daily health check'
)

events.put_targets(
    Rule='DailyHealthCheck',
    Targets=[{
        'Id': 'HealthCheckLambda',
        'Arn': 'arn:aws:lambda:us-east-1:123456789:function:health-check'
    }]
)
```

### Event Pattern Rule

```python
events.put_rule(
    Name='GlueJobFailure',
    EventPattern=json.dumps({
        "source": ["aws.glue"],
        "detail-type": ["Glue Job State Change"],
        "detail": {
            "state": ["FAILED", "TIMEOUT"]
        }
    }),
    State='ENABLED'
)

events.put_targets(
    Rule='GlueJobFailure',
    Targets=[
        {
            'Id': 'NotifySNS',
            'Arn': 'arn:aws:sns:us-east-1:123456789:alerts',
            'InputTransformer': {
                'InputPathsMap': {
                    'jobName': '$.detail.jobName',
                    'state': '$.detail.state'
                },
                'InputTemplate': '"Glue job <jobName> entered state <state>"'
            }
        }
    ]
)
```

## Targets

| Target | Use Case |
|--------|----------|
| Lambda function | Event processing, automation |
| SNS topic | Notifications, fan-out |
| SQS queue | Buffered processing |
| Step Functions | Complex workflows |
| ECS task | Container-based processing |
| Kinesis stream | Stream processing |
| CloudWatch log group | Event archival |
| Systems Manager | Automated remediation |

## Schedule Expressions

| Expression | Description |
|------------|-------------|
| `rate(5 minutes)` | Every 5 minutes |
| `rate(1 hour)` | Every hour |
| `rate(1 day)` | Daily |
| `cron(0 12 * * ? *)` | Noon UTC daily |
| `cron(0 8 ? * MON-FRI *)` | 8 AM UTC weekdays |
| `cron(0/15 * * * ? *)` | Every 15 minutes |

## Common Mistakes

| Don't | Do |
|-------|-----|
| Use CloudWatch Events for new apps | Use EventBridge (same API, richer features) |
| Forget to add Lambda permissions | Add `lambda:InvokeFunction` resource policy |
| Use rate() for complex schedules | Use EventBridge Scheduler for one-time/complex |

## Related

- [Alarms](alarms.md) - Alarm state changes generate events
- [Alerting Pattern](../patterns/alerting-notifications.md) - Event-driven alerting
- [Lambda Monitoring](../patterns/lambda-monitoring.md) - Lambda event triggers
