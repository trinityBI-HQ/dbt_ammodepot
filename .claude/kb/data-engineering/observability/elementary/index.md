# Elementary Knowledge Base

> **Purpose**: Data & AI Control Plane (2.0) for anomaly detection, data quality monitoring, AI-powered triage, and unified pipeline observability
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/dbt-package.md](concepts/dbt-package.md) | The Elementary dbt package: installation, models, metadata collection |
| [concepts/anomaly-detection.md](concepts/anomaly-detection.md) | How anomaly detection works: Z-score, time buckets, sensitivity |
| [concepts/data-monitors.md](concepts/data-monitors.md) | Monitor types: freshness, volume, schema changes, dimension anomalies |
| [concepts/elementary-cli.md](concepts/elementary-cli.md) | The `edr` CLI: commands, report generation, alerting |
| [concepts/elementary-cloud.md](concepts/elementary-cloud.md) | Elementary Cloud: managed observability, AI agents, incident management |
| [concepts/test-results.md](concepts/test-results.md) | How Elementary collects and surfaces test results and run metadata |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/dbt-integration.md](patterns/dbt-integration.md) | Setting up Elementary with dbt: package, profile, models |
| [patterns/anomaly-monitoring.md](patterns/anomaly-monitoring.md) | Configuring anomaly detection monitors in schema.yml |
| [patterns/alerting-notifications.md](patterns/alerting-notifications.md) | Setting up Slack, Teams, email, and PagerDuty alerts |
| [patterns/dagster-integration.md](patterns/dagster-integration.md) | Running Elementary within Dagster pipelines |
| [patterns/custom-tests.md](patterns/custom-tests.md) | Writing custom tests and extending built-in monitors |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **dbt Package** | `elementary-data/elementary` dbt package that collects metadata and runs anomaly tests |
| **Anomaly Detection** | Z-score based detection with seasonality awareness and sensitivity tuning |
| **Data Monitors** | Pre-built monitors for freshness, volume, schema changes, dimensions; automated out-of-box monitors (no config) |
| **edr CLI** | Python CLI for generating reports and sending alerts |
| **Elementary 2.0** | Data & AI Control Plane with shared context engine, AI agents, business user workflows (Dec 2025) |
| **Test Results** | Metadata tables storing all dbt test and run results |

---

## Architecture

```
dbt Project
  +-- packages.yml (elementary-data/elementary)
  +-- schema.yml (Elementary test configs)
  |
  v
dbt run --select elementary  -->  Elementary metadata tables (in warehouse)
dbt test                     -->  Test results stored in elementary schema
  |
  v
edr CLI (pip install elementary-data)
  +-- edr report    -->  HTML observability report
  +-- edr monitor   -->  Send alerts (Slack, Teams, email)
  +-- edr send-report --> Generate + send report
  |
  v
Elementary 2.0 / Cloud (optional)
  +-- Data & AI Control Plane: shared context engine
  +-- AI agents for triage, test coverage, performance tuning
  +-- Unified SQL, Python, and AI pipeline observability
  +-- Column-level lineage with test results overlay
  +-- Business user workflows, incident management
```

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/dbt-package.md, concepts/data-monitors.md |
| **Intermediate** | patterns/dbt-integration.md, patterns/anomaly-monitoring.md, concepts/anomaly-detection.md |
| **Advanced** | patterns/custom-tests.md, patterns/dagster-integration.md, concepts/elementary-cloud.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dbt-expert | patterns/dbt-integration.md, patterns/anomaly-monitoring.md | Add observability to dbt projects |
| dagster-expert | patterns/dagster-integration.md | Orchestrate Elementary in Dagster |
| data-engineer | patterns/alerting-notifications.md, concepts/data-monitors.md | Monitor data quality |

---

## Project Context

This KB supports data observability workflows using Elementary:
- dbt-native anomaly detection with zero additional infrastructure
- Automated out-of-box monitors: freshness, volume, schema change (no manual config)
- Enhanced anomaly detection: seasonality awareness, where expressions, sensitivity tuning
- Column-level anomaly detection for data quality at scale
- Integration with Dagster for orchestrated observability
- Slack/Teams/email alerting for proactive incident response
- **Elementary 2.0** (Dec 2025): Data & AI Control Plane with shared context engine, AI agents, unified SQL/Python/AI pipeline observability, business user workflows, column-level lineage with test results
- Python 3.13 support (v0.22.0)
