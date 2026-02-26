# Elementary CLI (edr)

> **Purpose**: The `edr` command-line interface for generating reports and sending alerts
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Elementary CLI (`edr`) is a Python tool that connects to your data warehouse, reads from Elementary metadata tables, and generates observability reports or sends alerts. It is installed separately from the dbt package via `pip install elementary-data`. The CLI supports Slack, Microsoft Teams, email, S3, and GCS as output destinations.

## Installation

```bash
# Generic installation
pip install elementary-data

# Warehouse-specific (includes adapter dependencies)
pip install 'elementary-data[snowflake]'
pip install 'elementary-data[bigquery]'
pip install 'elementary-data[redshift]'
pip install 'elementary-data[databricks]'
pip install 'elementary-data[postgres]'

# Verify installation
edr --version
```

## Core Commands

### edr report

Generates an HTML observability report from Elementary test results.

```bash
# Generate report (default: ./edr_target/elementary_report.html)
edr report

# Custom output location
edr report --file-path /reports --file-name my_report.html

# Filter by selector
edr report --select tag:critical

# Specify days of history
edr report -d 7

# Set timezone for report timestamps
edr report -tz "US/Eastern"
```

### edr monitor

Reads test results and sends new alerts to configured channels.

```bash
# Send alerts to Slack via webhook
edr monitor -s https://hooks.slack.com/services/xxx/yyy/zzz

# Send alerts via Slack token + channel
edr monitor -st xoxb-your-token -ch data-alerts

# Set alert suppression interval (hours)
edr monitor --suppression-interval 4

# Filter alerts by selector
edr monitor --select tag:critical

# Set days back for alert window
edr monitor -d 3
```

### edr send-report

Generates a report and sends it to an external platform.

```bash
# Send report to Slack
edr send-report -st xoxb-your-token -ch data-reports

# Upload report to S3
edr send-report --s3-endpoint-url s3://my-bucket/reports/

# Upload report to GCS
edr send-report --gcs-bucket-name my-bucket --gcs-prefix reports/
```

## Common Options

| Option | Short | Description |
|--------|-------|-------------|
| `--profiles-dir` | `-p` | Path to profiles.yml directory |
| `--project-dir` | | Path to dbt_project.yml |
| `--config-dir` | `-c` | Path to config.yml (default: `~/.edr`) |
| `--target-path` | | Output directory (default: `./edr_target`) |
| `--profile-target` | `-t` | Elementary profile target name |
| `--days-back` | `-d` | Number of days to include |
| `--timezone` | `-tz` | Timezone for timestamps |
| `--env` | | Environment: `dev` or `prod` |
| `--disable-samples` | | Disable data samples in report |

## Environment Variables

All CLI options can be set via environment variables using the format:

```bash
EDR_<COMMAND>_<OPTION>=<VALUE>

# Examples
EDR_REPORT_FILE_PATH="/reports"
EDR_MONITOR_SLACK_WEBHOOK="https://hooks.slack.com/..."
EDR_MONITOR_DAYS_BACK=7
```

## Profile Configuration

The CLI uses the same `profiles.yml` as dbt, with an `elementary` profile target:

```yaml
# ~/.dbt/profiles.yml
elementary:
  outputs:
    default:
      type: snowflake
      account: my_account
      user: elementary_user
      password: "{{ env_var('ELEMENTARY_PASSWORD') }}"
      database: analytics
      schema: elementary
      warehouse: transforming
```

## Related

- [dbt-package](../concepts/dbt-package.md)
- [alerting-notifications](../patterns/alerting-notifications.md)
- [test-results](../concepts/test-results.md)
