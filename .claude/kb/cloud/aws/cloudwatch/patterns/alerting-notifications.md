# Alerting and Notifications

> **Purpose**: End-to-end alerting pipelines from CloudWatch alarms to SNS, ChatOps, and incident management
> **MCP Validated**: 2026-02-19

## When to Use

- Setting up production alerting for AWS workloads (Slack, PagerDuty, OpsGenie)
- Building tiered alert severity with composite alarms
- Reducing alert fatigue through noise reduction patterns

## Architecture: Alert Pipeline

```text
CloudWatch Alarm ──> SNS Topic ──> Email (on-call)
                          │
                          ├──> Lambda ──> Slack / Teams
                          │
                          ├──> PagerDuty (HTTPS endpoint)
                          │
                          └──> SQS ──> Incident tracking
```

## Implementation: SNS Alert Topic

```python
import boto3

sns = boto3.client('sns')

# Create alert topics by severity
for severity in ['critical', 'warning', 'info']:
    topic = sns.create_topic(Name=f'cloudwatch-alerts-{severity}')
    print(f"{severity}: {topic['TopicArn']}")

# Subscribe email
sns.subscribe(
    TopicArn='arn:aws:sns:us-east-1:123456789:cloudwatch-alerts-critical',
    Protocol='email',
    Endpoint='oncall@example.com'
)

# Subscribe HTTPS endpoint (PagerDuty)
sns.subscribe(
    TopicArn='arn:aws:sns:us-east-1:123456789:cloudwatch-alerts-critical',
    Protocol='https',
    Endpoint='https://events.pagerduty.com/integration/INTEGRATION_KEY/enqueue'
)
```

## Implementation: Slack Integration via Lambda

```python
import json
import os
import urllib.request

SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']

def handler(event, context):
    """Forward CloudWatch alarm to Slack via SNS trigger."""
    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])

        alarm_name = message['AlarmName']
        state = message['NewStateValue']
        reason = message['NewStateReason']
        timestamp = message['StateChangeTime']

        color = {
            'ALARM': '#d62728',
            'OK': '#2ca02c',
            'INSUFFICIENT_DATA': '#ff7f0e'
        }.get(state, '#808080')

        slack_message = {"attachments": [{"color": color,
            "title": f":rotating_light: {alarm_name}",
            "fields": [
                {"title": "State", "value": state, "short": True},
                {"title": "Time", "value": timestamp, "short": True},
                {"title": "Reason", "value": reason, "short": False}
            ], "footer": "CloudWatch Alarm"}]}

        req = urllib.request.Request(SLACK_WEBHOOK_URL,
            data=json.dumps(slack_message).encode('utf-8'),
            headers={'Content-Type': 'application/json'})
        urllib.request.urlopen(req)
```

## Implementation: Tiered Alerting with Composite Alarms

```python
import boto3

cw = boto3.client('cloudwatch')

# Individual metric alarms
cw.put_metric_alarm(
    AlarmName='API-HighErrorRate',
    Namespace='AWS/ApiGateway',
    MetricName='5XXError',
    Statistic='Sum',
    Period=300,
    EvaluationPeriods=2,
    Threshold=10,
    ComparisonOperator='GreaterThanThreshold',
    TreatMissingData='notBreaching'
)

cw.put_metric_alarm(
    AlarmName='API-HighLatency',
    Namespace='AWS/ApiGateway',
    MetricName='Latency',
    ExtendedStatistic='p99',
    Period=300,
    EvaluationPeriods=2,
    Threshold=5000,
    ComparisonOperator='GreaterThanThreshold',
    TreatMissingData='notBreaching'
)

# Composite alarm: only fire critical alert when BOTH are true
cw.put_composite_alarm(
    AlarmName='API-ServiceDegraded-CRITICAL',
    AlarmRule='ALARM("API-HighErrorRate") AND ALARM("API-HighLatency")',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:cloudwatch-alerts-critical']
)

# Individual alarms go to warning topic
cw.put_metric_alarm(
    AlarmName='API-HighErrorRate',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:cloudwatch-alerts-warning']
)
```

## Terraform: Complete Alert Stack

```hcl
resource "aws_sns_topic" "alerts" {
  for_each = toset(["critical", "warning", "info"])
  name     = "cloudwatch-alerts-${each.key}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts["critical"].arn
  protocol  = "email"
  endpoint  = var.oncall_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts["warning"].arn]
  ok_actions          = [aws_sns_topic.alerts["info"].arn]

  dimensions = {
    FunctionName = var.function_name
  }
}
```

## Alert Noise Reduction

| Strategy | How | Effect |
|----------|-----|--------|
| M-of-N evaluation | `DatapointsToAlarm=3, EvaluationPeriods=5` | Ignore transient spikes |
| Composite alarms | Combine related alarms with AND | Only alert on correlated failures |
| Missing data = notBreaching | `TreatMissingData='notBreaching'` | Prevent false alarms during deploys |
| OK actions | Send resolution notifications | Clear incident status |
| Suppressor alarms | Composite alarm with `ActionsSuppressor` | Mute during maintenance |

## Application Signals: SLO-Based Alerting (2025)

Application Signals provides APM with SLO-driven alerting. Key features added in 2025:

| Feature | Date | Description |
|---------|------|-------------|
| Cross-account SLOs | Feb 2025 | Single-pane-of-glass SLOs across accounts via OAM |
| SLO exclusion windows | Mar 2025 | Pause error budget burn during maintenance |
| Dependency SLOs | Apr 2025 | Track latency/faults on outgoing service calls |
| Service discovery | Nov 2025 | Auto-discover un-instrumented services |
| Cross-account views | Nov 2025 | Unified service map across accounts |
| Change history | Nov 2025 | Correlate SLO violations with deployments |

**Pattern**: Define SLOs on service latency/availability -> set error budget alarms -> use exclusion windows for planned maintenance -> track dependency SLOs for outgoing calls.

## Configuration

SNS retries: 3 (default, sufficient). Lambda Slack forwarder timeout: 30s. Use SNS filter policies for routing by severity.

## See Also

- [Alarms Concept](../concepts/alarms.md) -- [Events/EventBridge](../concepts/events-eventbridge.md) -- [Lambda Monitoring](lambda-monitoring.md)
