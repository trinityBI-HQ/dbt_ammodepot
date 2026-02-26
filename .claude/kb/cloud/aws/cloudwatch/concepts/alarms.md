# CloudWatch Alarms

> **Purpose**: Automated monitoring with threshold-based actions on metrics
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Alarms watch a single metric or a metric math expression and perform actions when the value crosses a threshold. Alarms have three states: OK, ALARM, and INSUFFICIENT_DATA. Actions can trigger SNS notifications, Auto Scaling policies, EC2 actions, or Systems Manager runbooks.

## Alarm States

| State | Meaning |
|-------|---------|
| **OK** | Metric is within the defined threshold |
| **ALARM** | Metric has breached the threshold |
| **INSUFFICIENT_DATA** | Not enough data to determine state (startup or missing data) |

## Alarm Types

### Standard Alarm

Watches a single metric against a static threshold.

```python
import boto3

client = boto3.client('cloudwatch')

client.put_metric_alarm(
    AlarmName='HighErrorRate',
    Namespace='AWS/Lambda',
    MetricName='Errors',
    Dimensions=[
        {'Name': 'FunctionName', 'Value': 'my-func'}
    ],
    Statistic='Sum',
    Period=300,
    EvaluationPeriods=2,
    DatapointsToAlarm=2,
    Threshold=5,
    ComparisonOperator='GreaterThanOrEqualToThreshold',
    TreatMissingData='notBreaching',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:alerts'],
    OKActions=['arn:aws:sns:us-east-1:123456789:alerts']
)
```

### Composite Alarm

Combines multiple alarms with AND/OR logic. Reduces alert noise.

```python
client.put_composite_alarm(
    AlarmName='ServiceDegraded',
    AlarmRule='ALARM("HighErrorRate") AND ALARM("HighLatency")',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:critical-alerts'],
    ActionsSuppressor='MaintenanceWindow',
    ActionsSuppressorWaitPeriod=120,
    ActionsSuppressorExtensionPeriod=60
)
```

### Anomaly Detection Alarm

Uses ML to learn normal patterns and alert on deviations.

```python
client.put_metric_alarm(
    AlarmName='AnomalousLatency',
    Metrics=[
        {
            'Id': 'm1',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/Lambda',
                    'MetricName': 'Duration',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': 'my-func'}
                    ]
                },
                'Period': 300,
                'Stat': 'Average'
            }
        },
        {
            'Id': 'ad1',
            'Expression': 'ANOMALY_DETECTION_BAND(m1, 2)'
        }
    ],
    ComparisonOperator='LessThanLowerOrGreaterThanUpperThreshold',
    EvaluationPeriods=3,
    ThresholdMetricId='ad1',
    TreatMissingData='missing',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:alerts']
)
```

## Missing Data Handling

| Value | Behavior |
|-------|----------|
| `breaching` | Treat missing data as breaching the threshold |
| `notBreaching` | Treat missing data as within threshold |
| `ignore` | Maintain current state |
| `missing` | Default -- alarm goes to INSUFFICIENT_DATA |

## Evaluation Constraints

- `Period * EvaluationPeriods` must be <= 86,400 seconds (24 hours)
- Use `DatapointsToAlarm` (M of N) to reduce flapping
- Example: 3 of 5 evaluation periods must breach to trigger alarm

## Quick Reference

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `Period` | Data aggregation interval | 300 (5 min) |
| `EvaluationPeriods` | Number of periods to evaluate | 3 |
| `DatapointsToAlarm` | M-of-N breaching required | 2 |
| `Threshold` | Static value to compare against | 10 |
| `ComparisonOperator` | How to compare | `GreaterThanThreshold` |

## Tag-Based Alarms (Sep 2025)

Create alarms scoped by AWS resource tags rather than explicit dimension values. Alarms automatically apply to all resources matching the tag filter.

```text
# Alarm on all Lambda functions tagged Environment=prod
Namespace:  AWS/Lambda
MetricName: Errors
Tag Filter: aws:lambda:function:tag/Environment = "prod"
Threshold:  > 5
```

## SLO Exclusion Time Windows (Mar 2025)

Application Signals SLOs support exclusion windows to pause error budget consumption during planned maintenance. This prevents deployments and scheduled downtime from burning SLO budget.

## Related

- [Metrics](metrics.md) - Data that alarms watch
- [Alerting Pattern](../patterns/alerting-notifications.md) - End-to-end alerting setup
- [Events/EventBridge](events-eventbridge.md) - Event-driven alarm responses
