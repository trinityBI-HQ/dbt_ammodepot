# Data Quality Knowledge Base

> **Last Updated:** 2026-02-12
> **Maintained By:** Claude Code Lab Team

## Overview

Data quality ensures that data in pipelines and warehouses is accurate, complete, consistent, timely, and valid. This subcategory covers frameworks and patterns for defining, measuring, and enforcing data quality across the modern data stack.

## Philosophy

**Build data quality systems that are:**
- **Declarative**: Express expectations as code, not manual checks
- **Automated**: Run validations in every pipeline execution
- **Observable**: Generate docs, alerts, and dashboards from results
- **Layered**: Validate at ingestion, transformation, and serving

**Avoid:**
- Manual spot-checking in notebooks
- Quality checks only in production (shift left)
- Ignoring partial failures (use `mostly` thresholds)
- Siloed quality rules (centralize in version control)

## Technologies

### [Great Expectations (GX)](great-expectations/)

**What it does:** Python framework for declarative data validation using Expectations -- verifiable assertions about data quality, schema, and statistical properties.

**When to use:**
- Validating DataFrames (Pandas, Spark) or SQL tables in pipelines
- Need for auto-generated data quality documentation (Data Docs)
- Integration with orchestrators (Dagster, Airflow) for pipeline gates
- Custom validation logic beyond simple null/unique checks

**Key capabilities:**
- 47+ built-in Expectations (null checks, ranges, regex, types, statistics)
- Fluent Python API for programmatic configuration (GX 1.x)
- Checkpoints with Actions (Slack, email, Data Docs updates)
- Support for Pandas, Spark, PostgreSQL, Snowflake, BigQuery, and more

**Alternatives:** dbt tests (SQL-native, simpler), Soda (SodaCL syntax), Deequ (Spark-native), Pandera (Pandas schema validation)

## Decision Framework

### When to Use What?

| Scenario | Recommended Tool | Why |
|----------|------------------|-----|
| SQL-based column tests | **dbt tests** | Built into transformation layer |
| DataFrame validation in Python | **Great Expectations** | Rich API, Data Docs, Actions |
| Spark-native profiling | **Deequ / GX + Spark** | Distributed validation |
| Simple schema checks | **Pandera** | Lightweight, Pandas-focused |
| Pipeline quality gates | **GX Checkpoints** | Orchestrator integration, alerting |
| Data contracts | **GX + dbt tests** | Layered validation approach |

### Layered Quality Strategy

```
Ingestion (Bronze)     --> Schema validation, row counts, freshness
Transformation (Silver) --> Referential integrity, business rules, dedup
Serving (Gold)          --> Statistical bounds, SLA compliance, completeness
```

## Integration Patterns

### GX + Dagster
Use Dagster asset checks with GX validations for pipeline quality gates.

### GX + dbt
Run GX validations on dbt model outputs; use dbt tests for SQL-layer checks and GX for statistical/custom validations.

### GX + Airflow
Use the Great Expectations Airflow provider or call GX Checkpoints from PythonOperator tasks.

## Related Knowledge

- **Orchestration**: See [orchestration/](../orchestration/) for Dagster pipeline patterns
- **Transformation**: See [transformation/](../transformation/) for dbt testing
- **Data Platforms**: See [data-platforms/](../data-platforms/) for Snowflake/BigQuery quality
- **AI/ML Validation**: See [ai-ml/validation/](../../ai-ml/validation/) for Pydantic schema validation

## Agents

- `/dagster-expert` - Asset checks and pipeline quality gates
- `/dbt-expert` - dbt tests and data quality macros

---

**Validate early, validate often, validate everywhere.**
