# Great Expectations Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Core Workflow

```
Data Context --> Data Source --> Data Asset --> Batch Definition
                                                     |
Expectation Suite <-- Expectations          Validation Definition
                                                     |
                                                Checkpoint --> Actions --> Data Docs
```

## Common Expectations

| Expectation | Purpose |
|-------------|---------|
| `ExpectColumnValuesToNotBeNull` | No nulls in column |
| `ExpectColumnValuesToBeUnique` | All values unique |
| `ExpectColumnValuesToBeBetween` | Values in numeric range |
| `ExpectColumnValuesToBeInSet` | Values from allowed set |
| `ExpectColumnValuesToMatchRegex` | Values match pattern |
| `ExpectColumnValuesToBeOfType` | Column data type check |
| `ExpectTableRowCountToBeBetween` | Row count in range |
| `ExpectColumnMeanToBeBetween` | Statistical mean check |
| `ExpectColumnMaxToBeBetween` | Max value in range |
| `ExpectColumnDistinctValuesToBeInSet` | Distinct values check |

## Data Source Methods

| Method | Backend |
|--------|---------|
| `context.data_sources.add_pandas()` | Pandas DataFrames |
| `context.data_sources.add_spark()` | PySpark DataFrames |
| `context.data_sources.add_postgres()` | PostgreSQL |
| `context.data_sources.add_snowflake()` | Snowflake |
| `context.data_sources.add_redshift()` | Amazon Redshift |
| `context.data_sources.add_sql()` | Generic SQLAlchemy |

## Data Asset Methods

| Method | Use Case |
|--------|----------|
| `add_dataframe_asset()` | In-memory DataFrames |
| `add_table_asset()` | Database table |
| `add_query_asset()` | Custom SQL query |

## Batch Definition Methods

| Method | Partitioning |
|--------|-------------|
| `add_batch_definition_whole_dataframe()` | All rows (DataFrame) |
| `add_batch_definition_whole_table()` | All rows (SQL) |
| `add_batch_definition_daily()` | By day column |
| `add_batch_definition_monthly()` | By month column |
| `add_batch_definition_yearly()` | By year column |

## Expectation Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `column` | str | Target column name |
| `mostly` | float | Fraction that must pass (0.0-1.0) |
| `severity` | str | `critical`, `warning`, or `info` |

## Checkpoint Actions

| Action | Purpose |
|--------|---------|
| `SlackNotificationAction` | Send Slack alerts |
| `UpdateDataDocsAction` | Rebuild Data Docs site |
| `EmailAction` | Send email notifications |
| `MicrosoftTeamsNotificationAction` | Send Teams alerts |

## Result Format Options

| Format | Detail Level |
|--------|-------------|
| `BOOLEAN_ONLY` | Just pass/fail |
| `BASIC` | Pass/fail + observed value |
| `SUMMARY` | Default; partial values + metrics |
| `COMPLETE` | All values and metrics |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use YAML config (0.x style) | Use fluent Python API (1.x) |
| Stay on GX Core 0.18 | Migrate to 1.x (0.18 EOL Oct 2025) |
| Validate all data at once | Use Batch Definitions to partition |
| Skip `mostly` parameter | Set fuzzy thresholds for real data |
| Ignore Data Docs | Configure UpdateDataDocsAction |
| Hardcode connection strings | Use `${ENV_VAR}` references |

## Links

- `concepts/data-context.md` | `concepts/expectations.md` | `concepts/checkpoints.md`
