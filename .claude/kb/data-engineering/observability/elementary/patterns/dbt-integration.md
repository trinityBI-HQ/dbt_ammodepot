# dbt Integration Pattern

> **Purpose**: Complete setup of Elementary within a dbt project from installation to first report
> **MCP Validated**: 2026-02-19

## When to Use

- Adding data observability to an existing dbt project
- Setting up automated data quality monitoring
- Need dbt-native anomaly detection without additional infrastructure
- Want to track test results and run history over time

## Implementation

### Step 1: Add the dbt Package

```yaml
# packages.yml (in your dbt project root)
packages:
  - package: elementary-data/elementary
    version: 0.22.1
```

### Step 2: Configure dbt_project.yml

```yaml
# dbt_project.yml
models:
  elementary:
    +schema: "elementary"  # Dedicated schema for Elementary tables

# Optional: Global Elementary test defaults
vars:
  # Anomaly detection defaults
  anomaly_sensitivity: 3
  days_back: 14
  backfill_days: 2
  time_bucket:
    period: day
    count: 1
  # Include Elementary in full refreshes
  elementary_full_refresh: true
```

### Step 3: Install and Build

```bash
# Install Elementary package
dbt deps

# Build Elementary metadata models (creates tables in warehouse)
dbt run --select elementary

# Verify tables were created
# Check your warehouse for: elementary.dbt_models, elementary.elementary_test_results, etc.
```

### Step 4: Add Elementary Tests

```yaml
# models/staging/schema.yml
models:
  - name: stg_orders
    config:
      elementary:
        timestamp_column: "ordered_at"
    tests:
      - elementary.volume_anomalies
      - elementary.freshness_anomalies:
          timestamp_column: "ordered_at"
      - elementary.schema_changes
    columns:
      - name: order_id
        tests:
          - not_null
          - unique
      - name: amount
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - average
                - null_percent
                - zero_percent
```

### Step 5: Install the CLI

```bash
# Install edr CLI with your warehouse adapter
pip install 'elementary-data[snowflake]'
# Or: pip install 'elementary-data[bigquery]'
# Or: pip install 'elementary-data[databricks]'
```

### Step 6: Configure CLI Profile

```yaml
# ~/.dbt/profiles.yml - Add Elementary profile
elementary:
  outputs:
    default:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      database: analytics
      schema: elementary
      warehouse: transforming
      role: elementary_role
```

### Step 7: Run Tests and Generate Report

```bash
# Run dbt tests (includes Elementary tests)
dbt test

# Generate HTML observability report
edr report

# Open the report
open edr_target/elementary_report.html
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `+schema` | `"elementary"` | Schema for Elementary tables |
| `elementary_full_refresh` | `false` | Include Elementary in `--full-refresh` |
| `anomaly_sensitivity` | `3` | Global Z-score threshold |
| `days_back` | `14` | Global training window |
| `disable_samples` | `false` | Disable data sample collection |

## CI/CD Integration

```yaml
# GitHub Actions example
- name: Run dbt tests with Elementary
  run: |
    dbt deps
    dbt run --select elementary
    dbt test
    edr report --file-path ./reports

- name: Upload Elementary Report
  uses: actions/upload-artifact@v4
  with:
    name: elementary-report
    path: ./reports/elementary_report.html
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Skip `dbt run --select elementary` | Always build Elementary models before testing |
| Use default schema (same as models) | Create dedicated `elementary` schema |
| Install `elementary-data` without adapter | Use `elementary-data[snowflake]` etc. |
| Hardcode credentials in profiles.yml | Use `env_var()` for all secrets |
| Run `edr` without running `dbt test` first | Always run tests before generating reports |

## See Also

- [dbt-package](../concepts/dbt-package.md)
- [anomaly-monitoring](../patterns/anomaly-monitoring.md)
- [alerting-notifications](../patterns/alerting-notifications.md)
