# AWS CloudWatch Knowledge Base

> **Purpose**: Full-stack observability for AWS resources -- metrics, logs, alarms, dashboards, and synthetics
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/metrics.md](concepts/metrics.md) | Namespaces, dimensions, math expressions, high-res metrics |
| [concepts/alarms.md](concepts/alarms.md) | Alarm states, composite alarms, anomaly detection |
| [concepts/logs.md](concepts/logs.md) | Log groups, streams, Insights query syntax, metric filters |
| [concepts/dashboards.md](concepts/dashboards.md) | Widgets, cross-account dashboards, annotations |
| [concepts/events-eventbridge.md](concepts/events-eventbridge.md) | CloudWatch Events, EventBridge rules, targets |
| [concepts/synthetics.md](concepts/synthetics.md) | Canaries, endpoint monitoring, availability checks |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/lambda-monitoring.md](patterns/lambda-monitoring.md) | Monitor Lambda with metrics, logs, and Lambda Insights |
| [patterns/log-aggregation.md](patterns/log-aggregation.md) | Centralized logging, cross-account, S3 export |
| [patterns/alerting-notifications.md](patterns/alerting-notifications.md) | SNS alerts, ChatOps, PagerDuty integration |
| [patterns/custom-metrics.md](patterns/custom-metrics.md) | SDK, EMF, StatsD, and CloudWatch Agent approaches |
| [patterns/cost-optimization.md](patterns/cost-optimization.md) | Reduce CloudWatch spend on logs, metrics, dashboards |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Metrics** | Time-series data points organized by namespace, name, and dimensions |
| **Alarms** | Watch a metric and trigger actions when thresholds are breached |
| **Logs** | Centralized log ingestion with Insights for SQL-like querying |
| **Dashboards** | Customizable visualizations of metrics and logs across accounts |
| **Events/EventBridge** | Event-driven rules that route AWS events to targets |
| **Synthetics** | Canary scripts that proactively test endpoints on a schedule |
| **Application Signals** | APM with cross-account SLOs, dependency tracking, change history |
| **Internet Monitor** | Monitor internet connectivity to your application |
| **Tag-Based Telemetry** | Alarms and queries using AWS resource tags, dynamic dashboards |
| **Cross-Account Logs** | Org-wide log centralization across accounts and regions |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/metrics.md, concepts/logs.md |
| **Intermediate** | concepts/alarms.md, patterns/lambda-monitoring.md |
| **Advanced** | patterns/custom-metrics.md, patterns/cost-optimization.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| lambda-builder | patterns/lambda-monitoring.md | Lambda observability setup |
| aws-lambda-architect | concepts/alarms.md, patterns/alerting-notifications.md | Alarm + SNS architecture |
| aws-deployer | patterns/custom-metrics.md | Deploy instrumented services |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| S3 | `../s3/` | S3 metrics, log export destination |
| Glue | `../glue/` | Glue job metrics and log monitoring |
| Athena | `../athena/` | Query exported CloudWatch logs |
| Terraform | `../../../devops-sre/iac/terraform/` | IaC for CloudWatch resources |
| Dagster | `../../../data-engineering/orchestration/dagster/` | Pipeline observability |
