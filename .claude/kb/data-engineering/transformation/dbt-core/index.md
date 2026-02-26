# dbt-core Knowledge Base

> **Purpose**: Open-source CLI tool for SQL-based data transformation in analytics engineering (v1.11.x)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/models.md](concepts/models.md) | SQL models, materializations, and the DAG |
| [concepts/sources.md](concepts/sources.md) | Declaring and documenting raw data sources |
| [concepts/refs.md](concepts/refs.md) | The ref() function and dependency management |
| [concepts/tests.md](concepts/tests.md) | Generic, singular, and unit tests for data quality |
| [concepts/materializations.md](concepts/materializations.md) | View, table, incremental, ephemeral, and microbatch |
| [concepts/jinja-macros.md](concepts/jinja-macros.md) | Jinja templating, reusable macros, and anchors |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/best-practices.md](patterns/best-practices.md) | Official dbt best practices (layer rules, anti-patterns, CI) |
| [patterns/style-guide.md](patterns/style-guide.md) | SQL, Jinja, and YAML style conventions |
| [patterns/project-structure.md](patterns/project-structure.md) | Staging, intermediate, marts organization |
| [patterns/incremental-models.md](patterns/incremental-models.md) | Efficient incremental loading strategies |
| [patterns/snapshots.md](patterns/snapshots.md) | SCD Type 2 implementation with snapshots |
| [patterns/testing-strategy.md](patterns/testing-strategy.md) | Comprehensive testing approach |
| [patterns/custom-macros.md](patterns/custom-macros.md) | Building reusable macro libraries |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Models** | SQL SELECT statements that define transformations |
| **ref()** | Function to reference other models, builds DAG |
| **source()** | Function to reference raw data sources |
| **Materializations** | How models are built: view, table, incremental, microbatch |
| **Tests** | Generic, singular, and unit tests for data quality |
| **Macros** | Reusable Jinja templates for DRY SQL |
| **UDFs** | User-defined functions via `function()` resource type (v1.11) |
| **Release Tracks** | Latest, Compatible, Extended replace version pinning |
| **Fusion Engine** | Native SQL parsing with live error detection (preview) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/models.md, concepts/refs.md, concepts/sources.md |
| **Intermediate** | concepts/tests.md, patterns/project-structure.md, patterns/style-guide.md |
| **Advanced** | patterns/best-practices.md, patterns/incremental-models.md, patterns/snapshots.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dbt-expert | patterns/best-practices.md, patterns/style-guide.md | Best practices and conventions |
| dbt-expert | patterns/project-structure.md | Organize dbt projects |
| dbt-expert | patterns/incremental-models.md | Build efficient transformations |
| dbt-expert | patterns/testing-strategy.md | Implement data quality tests |

---

## Project Context

This KB supports data transformation workflows using dbt-core:
- SQL-based transformations with Jinja templating
- Data modeling with dependency management via ref()
- Testing and documentation for data quality
- Incremental models for efficient large-scale processing
- Snapshots for SCD Type 2 historical tracking
- Microbatch incremental strategy for time-series data (v1.9+)
- User-defined functions (UDFs) as a resource type (v1.11)
- Unit tests for TDD-style model validation (v1.8+)
- Release Tracks replacing explicit version pinning
- dbt Fusion Engine for native SQL parsing (preview)
- Integration with Snowflake, BigQuery, Databricks, Redshift
