# Elementary Cloud

> **Purpose**: Elementary 2.0 Data & AI Control Plane -- managed observability with AI agents, shared context, and unified pipeline monitoring
> **Confidence**: 0.90
> **MCP Validated**: 2026-02-19

## Overview

Elementary 2.0 (Dec 2025) rebranded from a dbt observability tool to a full **Data & AI Control Plane**. It introduces a shared context engine (unified lineage, tests, incidents, performance), AI agents for triage/coverage/tuning, unified SQL/Python/AI pipeline support, business user workflows, and column-level lineage with test results overlay. It connects to your existing Elementary dbt package and provides a web-based control plane for organization-wide data reliability.

## OSS vs Elementary 2.0

| Feature | Elementary OSS | Elementary 2.0 (Cloud) |
|---------|---------------|------------------------|
| dbt package + tests | Yes | Yes |
| HTML reports | Yes (edr CLI) | Yes (web UI) |
| Slack/Teams alerts | Yes (edr CLI) | Yes (managed) |
| Automated monitors | No (manual config) | Yes (out-of-box, no config) |
| Column-level lineage | No | Yes (with test results overlay) |
| Shared context engine | No | Yes (unified lineage, tests, incidents, perf) |
| AI agents | No | Yes (triage, coverage, tuning) |
| Unified SQL/Python/AI | dbt only | SQL, Python, and AI pipelines |
| Business user workflows | No | Yes |
| Incident management | No | Yes |
| RBAC + audit logs | No | Yes |
| Multi-project support | Manual | Native |

## Automated Out-of-Box Monitors

Elementary 2.0 provides out-of-the-box monitoring that requires zero configuration:

- **Freshness monitors**: Auto-detect expected update frequency per table
- **Volume monitors**: Track row count patterns with seasonality awareness
- **Schema monitors**: Detect structural changes across all tables

No manual `schema.yml` config required -- monitors activate automatically on connected tables.

## Shared Context Engine (2.0)

The core of Elementary 2.0 is a unified context engine that connects:
- **Lineage** (column-level, cross-pipeline)
- **Test results** (overlaid on lineage graph)
- **Incidents** (grouped, routed, tracked)
- **Performance** metrics (query cost, execution time)

This shared context powers both AI agents and business user workflows.

## AI Agents (2.0)

Elementary 2.0 includes AI agents that operate on shared context:

| Agent | Purpose |
|-------|---------|
| **Triage** | Investigates failures using lineage + test history, identifies root cause |
| **Test Coverage** | Suggests tests based on table structure, usage, and gaps |
| **Performance Tuning** | Identifies expensive queries, suggests optimizations |

## Column-Level Lineage

Lineage from source to BI tool at the column level, with test results overlaid:

```
Source Table (Column A) [3 tests passing]
  --> dbt Model (Column B = transform(A)) [1 test failing]
    --> Dashboard (Metric X uses Column B) [impacted]
```

## Incident Management

Groups related failures into managed incidents:

- **Grouping**: Related test failures clustered into a single incident
- **Routing**: Alerts sent to owners based on severity and ownership
- **Tracking**: Incident lifecycle from detection to resolution
- **Integration**: PagerDuty, Slack, email, Microsoft Teams

## Architecture

```
Your Data Pipelines (SQL, Python, AI)
  |-- elementary dbt package (collects metadata)
  |
  v
Data Warehouse (Elementary schema)
  |
  v
Elementary 2.0 Control Plane
  |-- Shared context engine
  |-- Automated monitors (no config)
  |-- AI agents (triage, coverage, tuning)
  |-- Column-level lineage + test overlay
  |-- Business user workflows
  |-- Incident management + alerting
```

## Getting Started

1. Sign up at `app.elementary-data.com`
2. Install the Elementary dbt package (same as OSS)
3. Connect your warehouse with read-only credentials
4. Automated monitors activate immediately (no config)
5. AI agents begin analyzing context

## Related

- [dbt-package](../concepts/dbt-package.md)
- [data-monitors](../concepts/data-monitors.md)
- [alerting-notifications](../patterns/alerting-notifications.md)
