# dbt Cloud Knowledge Base

> **Purpose**: Cloud-based data transformation platform with Studio IDE, Fusion Engine, Mesh, Semantic Layer, and Release Tracks
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/projects-environments.md](concepts/projects-environments.md) | Projects, environments, Release Tracks, and deployment |
| [concepts/models-materializations.md](concepts/models-materializations.md) | SQL/Python models and materialization types |
| [concepts/sources-seeds.md](concepts/sources-seeds.md) | Source definitions and seed data loading |
| [concepts/testing.md](concepts/testing.md) | Data tests, unit tests, and custom tests |
| [concepts/snapshots.md](concepts/snapshots.md) | SCD Type 2 with timestamp and check strategies |
| [concepts/jinja-macros.md](concepts/jinja-macros.md) | Templating, custom macros, and packages |
| [concepts/jobs-scheduling.md](concepts/jobs-scheduling.md) | Jobs, runs, and scheduling configuration |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/incremental-models.md](patterns/incremental-models.md) | Efficient incremental processing strategies |
| [patterns/ci-cd-workflow.md](patterns/ci-cd-workflow.md) | CI jobs, merge jobs, and webhooks |
| [patterns/testing-strategy.md](patterns/testing-strategy.md) | Comprehensive testing approach |
| [patterns/dbt-mesh.md](patterns/dbt-mesh.md) | Cross-project references and governance (stable) |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for commands, materializations, and configs

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Models** | SQL/Python transformations that define your data logic |
| **Materializations** | view, table, incremental, ephemeral, microbatch |
| **Sources** | Declarations of raw data loaded by EL tools |
| **Tests** | Generic, singular, and unit tests for data quality |
| **Snapshots** | SCD Type 2 historical tracking of mutable data |
| **Jobs** | Scheduled or triggered execution of dbt commands |
| **Release Tracks** | Latest, Compatible, Extended replace version pinning |
| **Fusion Engine** | Native SQL parsing, live error detection (preview) |
| **dbt Mesh** | Cross-project ref(), contracts, versions, access (stable) |
| **Semantic Layer** | MetricFlow-based measures and metrics |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/projects-environments.md, concepts/models-materializations.md |
| **Intermediate** | concepts/testing.md, patterns/incremental-models.md |
| **Advanced** | patterns/dbt-mesh.md, concepts/snapshots.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| DataOps Agent | patterns/ci-cd-workflow.md | Setting up CI/CD pipelines |
| Analytics Engineer | concepts/models-materializations.md | Model development |
| Data Quality Agent | patterns/testing-strategy.md | Test implementation |
