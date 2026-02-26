# Elementary dbt Package

> **Purpose**: Core dbt package that collects metadata, artifacts, and test results for data observability
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Elementary dbt package (`elementary-data/elementary`) is the foundation of the Elementary observability platform. When added to a dbt project, it creates metadata tables in your data warehouse that capture test results, run results, and schema information. These tables power both the OSS CLI reports and Elementary Cloud dashboards. The package also includes a comprehensive suite of anomaly detection tests.

## The Pattern

```yaml
# packages.yml - Add Elementary to your dbt project
packages:
  - package: elementary-data/elementary
    version: 0.22.1
    ## Compatible with dbt >= 1.4.0
```

```yaml
# dbt_project.yml - Configure Elementary schema
models:
  elementary:
    +schema: "elementary"

# Optional: Include Elementary in full refreshes
vars:
  elementary_full_refresh: true
```

```bash
# Installation sequence
dbt deps                          # Install the package
dbt run --select elementary       # Build Elementary metadata models
dbt test                          # Run tests (results stored in Elementary tables)
```

## Metadata Tables Created

The package generates tables in your configured Elementary schema:

| Table | Purpose |
|-------|---------|
| `dbt_models` | Model definitions and metadata |
| `dbt_tests` | Test definitions and configurations |
| `dbt_sources` | Source definitions |
| `dbt_exposures` | Exposure definitions |
| `dbt_run_results` | Individual run results per model |
| `model_run_results` | Aggregated model run history |
| `snapshot_run_results` | Snapshot execution history |
| `dbt_invocations` | dbt command invocations |
| `elementary_test_results` | All Elementary test results with metadata |
| `dbt_columns` | Column-level metadata |
| `dbt_seeds` | Seed definitions |
| `dbt_metrics` | Metric definitions |

## Available Test Types

| Category | Tests |
|----------|-------|
| **Anomaly Detection** | `volume_anomalies`, `freshness_anomalies`, `event_freshness_anomalies`, `dimension_anomalies`, `column_anomalies`, `all_columns_anomalies` |
| **Schema** | `schema_changes`, `schema_changes_from_baseline`, `json_schema`, `exposure_validation` |
| **AI-Powered** | `ai_data_validation`, `unstructured_data_validation` (Cloud) |

## Supported Warehouses

| Warehouse | Adapter |
|-----------|---------|
| Snowflake | `elementary-data[snowflake]` |
| BigQuery | `elementary-data[bigquery]` |
| Redshift | `elementary-data[redshift]` |
| Databricks | `elementary-data[databricks]` |
| PostgreSQL | `elementary-data[postgres]` |

## Common Mistakes

### Wrong

```yaml
# Anti-pattern: Forgetting to run Elementary models before tests
# Tests will fail or produce no results without metadata tables
dbt test  # Elementary tables don't exist yet!
```

### Correct

```bash
# Always build Elementary models first, then run tests
dbt run --select elementary
dbt test
```

## Related

- [data-monitors](../concepts/data-monitors.md)
- [test-results](../concepts/test-results.md)
- [dbt-integration](../patterns/dbt-integration.md)
