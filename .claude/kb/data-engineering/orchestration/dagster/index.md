# Dagster Knowledge Base

> **Purpose**: Data orchestration platform for building, running, and observing data pipelines using software-defined assets
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/software-defined-assets.md](concepts/software-defined-assets.md) | Declarative data assets with lineage and observability |
| [concepts/definitions.md](concepts/definitions.md) | Definitions object and code locations |
| [concepts/resources.md](concepts/resources.md) | External service configuration and dependency injection |
| [concepts/io-managers.md](concepts/io-managers.md) | Storage abstraction for asset inputs/outputs |
| [concepts/jobs-ops-graphs.md](concepts/jobs-ops-graphs.md) | Imperative pipeline building blocks |
| [concepts/schedules-sensors.md](concepts/schedules-sensors.md) | Automated execution triggers |
| [concepts/partitions.md](concepts/partitions.md) | Data segmentation and backfills |
| [concepts/dagster-cloud.md](concepts/dagster-cloud.md) | Dagster+ managed platform features |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/dbt-integration.md](patterns/dbt-integration.md) | Orchestrating dbt models as Dagster assets |
| [patterns/testing-assets.md](patterns/testing-assets.md) | Unit testing and mocking resources |
| [patterns/project-structure.md](patterns/project-structure.md) | Organizing code for team success |
| [patterns/kubernetes-deployment.md](patterns/kubernetes-deployment.md) | Production deployment with Helm |
| [patterns/cloud-integrations.md](patterns/cloud-integrations.md) | BigQuery, Snowflake, S3, GCS patterns |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Software-Defined Assets** | Declarative data assets defined as Python functions |
| **Declarative Automation** | `AutomationCondition` for composable, testable auto-materialization (GA in v1.9) |
| **Definitions** | Container for all project assets, jobs, schedules, sensors, resources |
| **Resources** | Configurable external service connections (databases, APIs) |
| **IO Managers** | Storage abstraction for reading/writing asset data |
| **Partitions** | Data segmentation by time, category, or dynamic keys |
| **Sensors** | Event-driven pipeline triggers (job-less supported since v1.9) |
| **Schedules** | Time-based execution, cron expressions (job-less supported since v1.9) |
| **BI Integrations** | First-class Tableau, Power BI, Looker, Sigma assets in the DAG |
| **Airlift** | Incremental migration toolkit from Airflow to Dagster |
| **Dagster+ Compass** | AI analytics with natural language querying over operational data |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/software-defined-assets.md, concepts/definitions.md |
| **Intermediate** | concepts/resources.md, concepts/io-managers.md, patterns/project-structure.md |
| **Advanced** | patterns/dbt-integration.md, patterns/kubernetes-deployment.md, concepts/partitions.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| data-engineer | patterns/dbt-integration.md, patterns/cloud-integrations.md | Build production pipelines |
| devops-engineer | patterns/kubernetes-deployment.md, concepts/dagster-cloud.md | Deploy and monitor |
| qa-engineer | patterns/testing-assets.md | Implement pipeline tests |

---

## Project Context

This KB supports data orchestration workflows using Dagster:
- Software-defined assets with automatic lineage tracking
- Declarative automation via `AutomationCondition` (replaces deprecated `AutoMaterializePolicy`)
- BI integrations: Tableau, Power BI, Looker, Sigma as first-class assets
- Airlift toolkit for incremental Airflow-to-Dagster migration
- Integration with dbt, Spark, Snowflake, BigQuery, S3/GCS
- Testing patterns for reliable data pipelines
- Production deployment on Kubernetes or Dagster+
- Dagster+ Insights, Cost Insights, and Compass (AI analytics)
