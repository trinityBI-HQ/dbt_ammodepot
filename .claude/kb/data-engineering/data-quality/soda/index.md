# Soda Knowledge Base

> **Purpose**: Data quality testing platform using SodaCL checks language for validation, monitoring, and data contracts
> **MCP Validated**: 2026-02-19

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/sodacl.md](concepts/sodacl.md) | SodaCL language syntax and structure |
| [concepts/checks.md](concepts/checks.md) | Check types: numeric, missing, validity, schema, freshness |
| [concepts/data-sources.md](concepts/data-sources.md) | Data source connections (Snowflake, BigQuery, Postgres, etc.) |
| [concepts/soda-cloud.md](concepts/soda-cloud.md) | Soda Cloud features, incidents, agreements, anomaly detection |
| [patterns/check-patterns.md](patterns/check-patterns.md) | Common check patterns for different use cases |
| [patterns/ci-cd-integration.md](patterns/ci-cd-integration.md) | GitHub Actions, dbt, orchestrator integration |
| [patterns/monitoring-alerting.md](patterns/monitoring-alerting.md) | Alerts, incidents, SLAs, webhook notifications |
| [quick-reference.md](quick-reference.md) | Fast lookup tables and common commands |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Soda Core** | Open-source CLI and Python library for running data quality scans |
| **SodaCL** | YAML-based DSL for defining data quality checks |
| **Soda Cloud** | SaaS platform for monitoring, alerting, incidents, and data contracts |
| **Soda Agent** | Hosted or self-hosted deployment that executes scans |
| **Check** | A single data quality assertion with a metric and threshold |
| **Scan** | Execution of checks against a data source |

## Installation

```bash
# Install for your data source (v4 packages)
pip install soda-postgres    # or soda-snowflake, soda-bigquery, soda-databricks, soda-spark
# Legacy v3: pip install soda-core-postgres~=3.5.0
```

## Quickstart

```yaml
# configuration.yml
data_source my_postgres:
  type: postgres
  connection:
    host: localhost
    port: 5432
    user: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    database: my_db
```

```yaml
# checks.yml
checks for orders:
  - row_count > 0
  - missing_count(customer_id) = 0
  - duplicate_count(order_id) = 0
  - freshness(created_at) < 1d
```

```bash
soda scan -d my_postgres -c configuration.yml checks.yml
```

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/sodacl.md, concepts/checks.md |
| **Intermediate** | concepts/data-sources.md, patterns/check-patterns.md |
| **Advanced** | concepts/soda-cloud.md, patterns/ci-cd-integration.md, patterns/monitoring-alerting.md |

## Soda vs Great Expectations

| Factor | Soda | Great Expectations |
|--------|------|--------------------|
| **Check Language** | YAML (SodaCL) | Python API (fluent) |
| **Learning Curve** | Low (YAML-first) | Medium (Python required) |
| **SaaS Platform** | Soda Cloud (built-in) | GX Cloud (separate) |
| **Data Contracts** | Native support | Not built-in |
| **Anomaly Detection** | ML-powered (Cloud) | Manual thresholds |
| **Best For** | Declarative checks, contracts | Programmatic validation, custom logic |
