# Great Expectations (GX) Knowledge Base

> **Purpose**: Python data quality and validation framework using declarative Expectations
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/data-sources.md](concepts/data-sources.md) | Connecting to Pandas, Spark, and SQL backends |
| [concepts/expectations.md](concepts/expectations.md) | Verifiable assertions about data quality |
| [concepts/expectation-suites.md](concepts/expectation-suites.md) | Grouping expectations for batch validation |
| [concepts/checkpoints.md](concepts/checkpoints.md) | Running validations with actions in production |
| [concepts/data-context.md](concepts/data-context.md) | GX configuration, project structure, stores |
| [concepts/data-docs.md](concepts/data-docs.md) | Auto-generated HTML documentation |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/pipeline-integration.md](patterns/pipeline-integration.md) | Integrating GX in Dagster, Airflow, dbt pipelines |
| [patterns/checkpoint-actions.md](patterns/checkpoint-actions.md) | Slack alerts, email, custom actions on results |
| [patterns/custom-expectations.md](patterns/custom-expectations.md) | Building custom expectation classes |
| [patterns/spark-validation.md](patterns/spark-validation.md) | Using GX with PySpark DataFrames |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables and common commands

---

## Installation

```bash
pip install great_expectations

# With optional backends
pip install 'great_expectations[spark]'      # PySpark support
pip install 'great_expectations[snowflake]'  # Snowflake support
pip install 'great_expectations[postgresql]' # PostgreSQL support
pip install 'great_expectations[bigquery]'   # BigQuery support
pip install 'great_expectations[redshift]'  # Amazon Redshift support (Jun 2025)
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Data Context** | Entry point for all GX operations; manages config and metadata |
| **Data Source** | Connection to a data store (database, filesystem, DataFrame) |
| **Data Asset** | Collection of records within a Data Source (table, query, file) |
| **Batch Definition** | How to organize records for validation (whole table, partitioned) |
| **Expectation** | A single verifiable assertion about data quality |
| **Expectation Suite** | Collection of Expectations applied together |
| **Validation Definition** | Links a Batch Definition to an Expectation Suite |
| **Checkpoint** | Runs Validation Definitions and triggers Actions |
| **Actions** | Post-validation hooks (alerts, Data Docs updates) |
| **Data Docs** | Auto-generated HTML documentation of results |

## Quickstart

```python
import great_expectations as gx

# 1. Get a Data Context
context = gx.get_context()

# 2. Connect to data
data_source = context.data_sources.add_pandas(name="my_source")
data_asset = data_source.add_dataframe_asset(name="my_asset")
batch_def = data_asset.add_batch_definition_whole_dataframe("my_batch")

# 3. Create expectations
suite = context.suites.add(gx.ExpectationSuite(name="my_suite"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column="id"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(
    column="age", min_value=0, max_value=120
))

# 4. Validate
validation_def = gx.ValidationDefinition(
    data=batch_def, suite=suite, name="my_validation"
)
context.validation_definitions.add(validation_def)
result = validation_def.run(batch_parameters={"dataframe": df})
print(result.success)  # True or False
```

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/data-context.md, concepts/expectations.md |
| **Intermediate** | concepts/data-sources.md, concepts/expectation-suites.md, concepts/checkpoints.md |
| **Advanced** | patterns/custom-expectations.md, patterns/spark-validation.md, patterns/pipeline-integration.md |

---

## Project Context

This KB supports data quality workflows using Great Expectations (GX Core 1.4-1.11):
- Declarative data validation with 47+ built-in Expectations
- Fluent Python API with cleaner APIs and typed parameters (1.4+)
- Multi-backend support: Pandas, Spark, PostgreSQL, Snowflake, BigQuery, Redshift
- Integration with Dagster, Airflow, dbt, and Atlan (Aug 2025)
- Auto-generated Data Docs for quality reporting
- Checkpoint-based production deployments with alerting
- Python 3.13 support (GX Core 1.x series)
- **ExpectAI** (GX Cloud): AI-driven Expectation generation from plain English (Feb/Jul 2025)
- **Data Health Dashboard** (GX Cloud): Daily health score, coverage metrics, failure ranking (Jul 2025)
- **Enhanced SQL Expectations** (GX Cloud): Inline SQL prompts, draft-before-save (Aug 2025)
- **GX Core 0.18 EOL**: Support ended Oct 1, 2025 -- migration to 1.x required
