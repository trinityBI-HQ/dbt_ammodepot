# Test Results

> **Purpose**: How Elementary collects, stores, and surfaces dbt test results and run metadata
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Elementary automatically captures all dbt test results, run results, and invocation metadata into dedicated tables in your data warehouse. This data powers the observability report, alerting, and trend analysis. Every `dbt test` run stores detailed results including status, execution time, failure messages, and data samples -- providing full historical observability over your data quality.

## How Collection Works

```
dbt test
  |
  +-- Standard dbt tests (not_null, unique, etc.)
  |     Result --> elementary_test_results table
  |
  +-- Elementary tests (volume_anomalies, etc.)
  |     Result + metrics --> elementary_test_results table
  |
  +-- Run metadata
        Result --> dbt_run_results, dbt_invocations tables
```

Elementary hooks into dbt's on-run-end to capture artifacts and store them in the Elementary schema.

## Key Tables

### elementary_test_results

The primary table for all test outcomes:

| Column | Description |
|--------|-------------|
| `test_unique_id` | Unique identifier for the test |
| `model_unique_id` | Model the test runs against |
| `test_name` | Name of the test (e.g., `volume_anomalies`) |
| `test_type` | `dbt_test` or `elementary_test` |
| `status` | `pass`, `fail`, `warn`, `error` |
| `detected_at` | Timestamp of detection |
| `test_results_description` | Human-readable failure description |
| `test_results_query` | SQL query that produced the result |
| `test_params` | JSON of test configuration parameters |
| `severity` | Test severity level |

### dbt_run_results

Captures execution results for every model, seed, and snapshot:

| Column | Description |
|--------|-------------|
| `unique_id` | Model unique identifier |
| `status` | `success`, `error`, `skipped` |
| `execution_time` | Time in seconds |
| `rows_affected` | Number of rows processed |
| `generated_at` | Timestamp of execution |

### dbt_invocations

Tracks each dbt command execution:

| Column | Description |
|--------|-------------|
| `invocation_id` | Unique dbt invocation ID |
| `command` | dbt command executed (run, test, build) |
| `dbt_version` | Version of dbt used |
| `project_name` | dbt project name |
| `generated_at` | Invocation timestamp |
| `full_refresh` | Whether full refresh was used |

## Querying Test Results

```sql
-- Find all failed tests in the last 7 days
SELECT
    test_name,
    model_unique_id,
    status,
    test_results_description,
    detected_at
FROM {{ ref('elementary', 'elementary_test_results') }}
WHERE status = 'fail'
  AND detected_at >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY detected_at DESC;

-- Find models with most test failures
SELECT
    model_unique_id,
    COUNT(*) AS failure_count
FROM {{ ref('elementary', 'elementary_test_results') }}
WHERE status = 'fail'
  AND detected_at >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY model_unique_id
ORDER BY failure_count DESC
LIMIT 10;
```

## Test Result Flow

```
dbt test run
  --> Elementary on-run-end hook
    --> Parse test artifacts (manifest.json, run_results.json)
      --> Insert into elementary_test_results
        --> edr CLI reads table
          --> Generate report / send alerts
```

## Data Samples

By default, Elementary captures sample rows that caused test failures. This helps debug issues without manually querying the warehouse. Disable with:

```bash
edr report --disable-samples true
edr monitor --disable-samples true
```

Or in `dbt_project.yml`:

```yaml
vars:
  disable_samples: true
```

## Common Mistakes

### Wrong

```sql
-- Anti-pattern: Querying elementary tables without running elementary models
-- Tables may be empty or stale
SELECT * FROM elementary.elementary_test_results;
```

### Correct

```bash
# Always run elementary models first to ensure tables are populated
dbt run --select elementary
dbt test
# Now query results or generate report
edr report
```

## Related

- [dbt-package](../concepts/dbt-package.md)
- [elementary-cli](../concepts/elementary-cli.md)
- [alerting-notifications](../patterns/alerting-notifications.md)
