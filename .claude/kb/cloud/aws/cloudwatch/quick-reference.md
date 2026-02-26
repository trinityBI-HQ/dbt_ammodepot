# CloudWatch Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Essential CLI Commands

| Command | Description |
|---------|-------------|
| `aws cloudwatch list-metrics --namespace AWS/Lambda` | List metrics for a namespace |
| `aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Invocations --start-time ... --end-time ... --period 300 --statistics Sum` | Get metric data |
| `aws cloudwatch put-metric-data --namespace Custom --metric-name Errors --value 1` | Publish custom metric |
| `aws cloudwatch put-metric-alarm --alarm-name HighErrors --namespace Custom --metric-name Errors --threshold 10 --comparison-operator GreaterThanThreshold --evaluation-periods 1 --period 300 --statistic Sum --alarm-actions arn:aws:sns:...` | Create alarm |
| `aws cloudwatch describe-alarms --state-value ALARM` | List active alarms |
| `aws logs create-log-group --log-group-name /app/prod` | Create log group |
| `aws logs put-retention-policy --log-group-name /app/prod --retention-in-days 30` | Set retention |
| `aws logs start-query --log-group-name /app/prod --query-string 'fields @timestamp, @message \| filter @message like /ERROR/' --start-time ... --end-time ...` | Run Insights query |

## Key Metric Namespaces

| Namespace | Service | Key Metrics |
|-----------|---------|-------------|
| `AWS/Lambda` | Lambda | Invocations, Duration, Errors, Throttles, ConcurrentExecutions |
| `AWS/S3` | S3 | BucketSizeBytes, NumberOfObjects, AllRequests |
| `AWS/EC2` | EC2 | CPUUtilization, NetworkIn, NetworkOut, StatusCheckFailed |
| `AWS/RDS` | RDS | CPUUtilization, FreeableMemory, ReadLatency |
| `AWS/ECS` | ECS | CPUUtilization, MemoryUtilization |
| `AWS/ApiGateway` | API GW | Count, 4XXError, 5XXError, Latency |
| `AWS/SQS` | SQS | NumberOfMessagesSent, ApproximateAgeOfOldestMessage |
| `AWS/Glue` | Glue | glue.driver.aggregate.bytesRead, glue.driver.aggregate.elapsedTime |

## Retention Defaults

| Data Type | Retention | Notes |
|-----------|-----------|-------|
| Metrics (< 60s period) | 3 hours | High-resolution |
| Metrics (60s period) | 15 days | Standard resolution |
| Metrics (5-min period) | 63 days | Aggregated |
| Metrics (1-hour period) | 15 months | Long-term |
| Logs | Never expire | Set retention policy to control cost |
| Dashboards | Indefinite | $3/dashboard/month after free tier |

## Logs Insights Quick Syntax

| Command | Example |
|---------|---------|
| `fields` | `fields @timestamp, @message` |
| `filter` | `filter @message like /ERROR/` |
| `parse` | `parse @message "User * performed *" as user, action` |
| `stats` | `stats count(*) by bin(1h)` |
| `sort` | `sort @timestamp desc` |
| `limit` | `limit 100` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Simple threshold alert | Standard Alarm |
| Alert on multiple conditions | Composite Alarm |
| Detect unusual patterns | Anomaly Detection Alarm |
| Proactive endpoint testing | Synthetics Canary |
| Cross-account monitoring | Cross-Account Observability |
| APM / service dependencies | Application Signals |
| Cross-account SLOs | Application Signals + OAM |
| Tag-based dynamic alerting | Tag-Based Telemetry |
| Org-wide log centralization | Cross-Account Log Copy (first copy free) |
| AI canary failure diagnosis | Synthetics MCP Server |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Leave log retention at default (forever) | Set retention policy (7, 14, 30, 60 days) |
| Publish high-cardinality dimensions | Use max 30 dimensions; avoid unique IDs |
| Create one alarm per metric manually | Use CloudFormation/Terraform for alarm-as-code |
| Ignore the CloudWatch free tier | 10 custom metrics, 5 GB log ingestion, 3 dashboards free |
| Store all logs in CloudWatch | Export infrequent logs to S3 for cheaper storage |
| Hardcode account IDs in dashboards | Use tag-based telemetry for dynamic scoping |
| Set up per-account log pipelines manually | Use cross-account log centralization (first copy free) |

## Related Documentation

| Topic | Path |
|-------|------|
| Metrics Deep Dive | `concepts/metrics.md` |
| Alarm Configuration | `concepts/alarms.md` |
| Log Analysis | `concepts/logs.md` |
| Full Index | `index.md` |
