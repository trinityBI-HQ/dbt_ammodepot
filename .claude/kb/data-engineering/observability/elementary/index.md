# Elementary Knowledge Base

> **Purpose**: Data & AI Control Plane (2.0) for anomaly detection, data quality monitoring, and unified pipeline observability
> **MCP Validated**: 2026-02-19

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/dbt-package.md](concepts/dbt-package.md) | Elementary dbt package: installation, models, metadata collection |
| [concepts/anomaly-detection.md](concepts/anomaly-detection.md) | Z-score detection, time buckets, sensitivity tuning |
| [concepts/data-monitors.md](concepts/data-monitors.md) | Monitor types: freshness, volume, schema changes, dimension anomalies |
| [concepts/elementary-cli.md](concepts/elementary-cli.md) | `edr` CLI: commands, report generation, alerting |
| [concepts/elementary-cloud.md](concepts/elementary-cloud.md) | Elementary Cloud: managed observability, AI agents, incident management |
| [concepts/test-results.md](concepts/test-results.md) | Test results collection and run metadata surfacing |
| [patterns/dbt-integration.md](patterns/dbt-integration.md) | Setting up Elementary with dbt: package, profile, models |
| [patterns/anomaly-monitoring.md](patterns/anomaly-monitoring.md) | Configuring anomaly detection monitors in schema.yml |
| [patterns/alerting-notifications.md](patterns/alerting-notifications.md) | Slack, Teams, email, and PagerDuty alerts |
| [patterns/dagster-integration.md](patterns/dagster-integration.md) | Running Elementary within Dagster pipelines |
| [patterns/custom-tests.md](patterns/custom-tests.md) | Writing custom tests and extending built-in monitors |
| [quick-reference.md](quick-reference.md) | Fast lookup tables |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **dbt Package** | `elementary-data/elementary` -- collects metadata and runs anomaly tests |
| **Anomaly Detection** | Z-score based with seasonality awareness and sensitivity tuning |
| **Data Monitors** | Freshness, volume, schema changes, dimensions; automated out-of-box (no config) |
| **edr CLI** | Python CLI for generating reports and sending alerts |
| **Elementary 2.0** | Data & AI Control Plane: shared context engine, AI agents, business user workflows |
| **Test Results** | Metadata tables storing all dbt test and run results |

## Architecture

```
dbt Project
  +-- packages.yml (elementary-data/elementary)
  +-- schema.yml (Elementary test configs)
  v
dbt run --select elementary  -->  Elementary metadata tables (in warehouse)
dbt test                     -->  Test results in elementary schema
  v
edr CLI (pip install elementary-data)
  +-- edr report / edr monitor / edr send-report
  v
Elementary 2.0 / Cloud (optional)
  +-- Shared context engine, AI agents for triage
  +-- Unified SQL/Python/AI pipeline observability
  +-- Column-level lineage with test results overlay
```

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/dbt-package.md, concepts/data-monitors.md |
| **Intermediate** | patterns/dbt-integration.md, patterns/anomaly-monitoring.md, concepts/anomaly-detection.md |
| **Advanced** | patterns/custom-tests.md, patterns/dagster-integration.md, concepts/elementary-cloud.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dbt-expert | patterns/dbt-integration.md, patterns/anomaly-monitoring.md | Add observability to dbt projects |
| dagster-expert | patterns/dagster-integration.md | Orchestrate Elementary in Dagster |
| data-engineer | patterns/alerting-notifications.md, concepts/data-monitors.md | Monitor data quality |

## Project Context

dbt-native anomaly detection with zero additional infrastructure. Automated out-of-box monitors (freshness, volume, schema). Column-level anomaly detection. Slack/Teams/email alerting. **Elementary 2.0** (Dec 2025): Data & AI Control Plane with shared context engine, AI agents, unified observability. Python 3.13 support (v0.22.0).
