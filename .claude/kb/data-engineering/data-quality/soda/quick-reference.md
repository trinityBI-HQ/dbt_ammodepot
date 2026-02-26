# Soda Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Core Workflow

```
configuration.yml --> checks.yml --> soda scan --> Results
   (connection)      (SodaCL)       (CLI/Python)   (pass/warn/fail)
```

## CLI Commands

| Command | Purpose |
|---------|---------|
| `soda scan -d SOURCE -c config.yml checks.yml` | Run checks |
| `soda test-connection -d SOURCE -c config.yml` | Test connection |
| `soda update-dro -d SOURCE -c config.yml` | Update distribution reference |

## Install Packages (v4)

| Data Source | Package |
|-------------|---------|
| PostgreSQL | `pip install soda-postgres` |
| Snowflake | `pip install soda-snowflake` |
| BigQuery | `pip install soda-bigquery` |
| Databricks | `pip install soda-databricks` |
| Redshift | `pip install soda-redshift` |
| Spark | `pip install soda-spark` |
| DuckDB | `pip install soda-duckdb` |
| MySQL | `pip install soda-mysql` |

## Numeric Metrics

| Metric | Example |
|--------|---------|
| `row_count` | `row_count > 0` |
| `avg(col)` | `avg(price) between 10 and 100` |
| `min(col)` / `max(col)` | `max(age) <= 120` |
| `sum(col)` | `sum(revenue) > 0` |
| `duplicate_count(col)` | `duplicate_count(id) = 0` |
| `duplicate_percent(col)` | `duplicate_percent(email) < 1%` |
| `stddev(col)` | `stddev(temperature) < 5` |

## Missing and Validity Metrics

| Metric | Example |
|--------|---------|
| `missing_count(col)` | `missing_count(name) = 0` |
| `missing_percent(col)` | `missing_percent(email) < 5%` |
| `invalid_count(col)` | `invalid_count(email) = 0` |
| `invalid_percent(col)` | `invalid_percent(phone) < 2%` |

## Unique Check Types

| Type | Purpose |
|------|---------|
| `freshness` | Validate data recency |
| `schema` | Validate columns and types |
| `reference` | Cross-dataset value matching |
| `cross` | Row count comparison between datasets |
| `anomaly detection` | ML-based anomaly detection (Cloud) |
| `failed rows` | Row-level business logic |

## Alert Thresholds

```yaml
- missing_count(email):
    warn: when > 5
    fail: when > 50
```

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Hardcode credentials in YAML | Use `${ENV_VAR}` references |
| Skip `freshness` checks | Always monitor data recency |
| Write one giant checks file | Split by dataset or domain |
| Ignore warn-level alerts | Set both warn and fail thresholds |
| Run checks without CI/CD | Integrate into pipeline workflows |

## Related

| Topic | Path |
|-------|------|
| SodaCL Syntax | `concepts/sodacl.md` |
| Check Types | `concepts/checks.md` |
| Data Sources | `concepts/data-sources.md` |
| Great Expectations | `../great-expectations/` |
