# Elementary Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Installation

| Step | Command |
|------|---------|
| Add dbt package | `packages.yml`: `elementary-data/elementary` version `0.22.1` |
| Install deps | `dbt deps` |
| Build models | `dbt run --select elementary` |
| Install CLI | `pip install elementary-data` or `pip install 'elementary-data[snowflake]'` |

## CLI Commands (edr)

| Command | Purpose |
|---------|---------|
| `edr report` | Generate HTML observability report |
| `edr monitor` | Read test results, send new alerts |
| `edr send-report` | Generate report and send to Slack/S3/GCS |
| `edr report --select tag:critical` | Filter report by selector |
| `edr monitor -d 7` | Monitor with 7 days lookback |

## Anomaly Detection Tests

| Test | Monitors | Config Required |
|------|----------|-----------------|
| `elementary.volume_anomalies` | Row count over time | `timestamp_column` |
| `elementary.freshness_anomalies` | Time between updates | `timestamp_column` |
| `elementary.event_freshness_anomalies` | Event load latency | `timestamp_column` |
| `elementary.dimension_anomalies` | Distribution by category | `dimensions` list |
| `elementary.column_anomalies` | Column-level metrics | `column_anomalies` list |
| `elementary.all_columns_anomalies` | All columns at once | `timestamp_column` |
| `elementary.schema_changes` | DDL changes | None |
| `elementary.schema_changes_from_baseline` | Compare to baseline | Column definitions |

## Key Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `timestamp_column` | None | Column for time bucketing |
| `anomaly_sensitivity` | `3` | Z-score threshold |
| `time_bucket.period` | `day` | Bucket granularity (hour/day/week) |
| `time_bucket.count` | `1` | Number of periods per bucket |
| `days_back` | `14` | Training window for anomaly model |
| `backfill_days` | `2` | Days to re-evaluate |
| `where_expression` | None | SQL filter for test data |
| `anomaly_direction` | `both` | `spike`, `drop`, or `both` |

## Column Anomaly Types

| Type | Description |
|------|-------------|
| `null_count` / `null_percent` | Null value tracking |
| `zero_count` / `zero_percent` | Zero value tracking |
| `average` / `min` / `max` / `sum` | Numeric statistics |
| `standard_deviation` / `variance` | Distribution metrics |
| `count_distinct` | Cardinality changes |
| `missing_count` / `missing_percent` | Missing value detection |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Monitor table row counts | `elementary.volume_anomalies` |
| Track data update frequency | `elementary.freshness_anomalies` |
| Detect column drift | `elementary.column_anomalies` |
| Monitor all columns at once | `elementary.all_columns_anomalies` |
| Track DDL changes | `elementary.schema_changes` |
| Monitor categorical distribution | `elementary.dimension_anomalies` |
| Validate with natural language | `elementary.ai_data_validation` (Cloud) |
| AI triage + root cause | Elementary 2.0 AI agents |
| Automated monitors (no config) | Elementary 2.0 out-of-box freshness/volume/schema |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Skip `dbt run --select elementary` | Run Elementary models before tests |
| Use very low `anomaly_sensitivity` | Start with default 3, tune down gradually |
| Monitor without `timestamp_column` | Always configure timestamp for time-series tests |
| Ignore `days_back` setting | Set training window appropriate to data cadence |
| Alert on every test failure | Use `group_alerts_by: table` to reduce noise |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/dbt-package.md` |
| Monitor Types | `concepts/data-monitors.md` |
| Elementary 2.0 | `concepts/elementary-cloud.md` |
| Alerting Setup | `patterns/alerting-notifications.md` |
