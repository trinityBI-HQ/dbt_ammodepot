# Dagster Integration Pattern

> **Purpose**: Running Elementary within Dagster pipelines for orchestrated data observability
> **MCP Validated**: 2026-02-19

## When to Use

- Orchestrating dbt + Elementary tests within Dagster pipelines
- Need Elementary reports generated after Dagster-managed dbt runs
- Want to trigger alerts via Dagster sensors based on test results
- Building end-to-end observable pipelines with asset checks

## Implementation

### Basic: Elementary Models as Dagster dbt Assets

When using `dagster-dbt`, Elementary models are automatically included as assets. The key is ensuring Elementary models run before tests execute.

```python
# assets.py - dbt assets including Elementary
from dagster import AssetExecutionContext
from dagster_dbt import DbtCliResource, dbt_assets
from .project import my_project

@dbt_assets(manifest=my_project.manifest_path)
def my_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()
```

### Running Elementary CLI from Dagster

```python
# assets.py - Elementary report generation as a Dagster asset
import subprocess
from dagster import asset, AssetExecutionContext, MaterializeResult

@asset(
    deps=["my_dbt_assets"],
    group_name="observability",
    description="Generate Elementary observability report",
)
def elementary_report(context: AssetExecutionContext) -> MaterializeResult:
    """Generate Elementary HTML report after dbt tests complete."""
    result = subprocess.run(
        [
            "edr", "report",
            "--profiles-dir", "/path/to/profiles",
            "--file-path", "/reports",
            "--file-name", "elementary_report.html",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        context.log.error(f"Elementary report failed: {result.stderr}")
        raise Exception(f"edr report failed: {result.stderr}")

    context.log.info("Elementary report generated successfully")
    return MaterializeResult(
        metadata={
            "report_path": "/reports/elementary_report.html",
            "stdout": result.stdout[-500:],
        }
    )
```

### Elementary Alerts via Dagster

```python
# assets.py - Elementary alerting as a Dagster asset
import subprocess
from dagster import asset, AssetExecutionContext, EnvVar

@asset(
    deps=["my_dbt_assets"],
    group_name="observability",
    description="Send Elementary alerts to Slack",
)
def elementary_alerts(context: AssetExecutionContext) -> None:
    """Send Elementary alerts after dbt tests complete."""
    slack_token = EnvVar("SLACK_BOT_TOKEN").get_value()
    slack_channel = EnvVar("SLACK_ALERT_CHANNEL").get_value()

    result = subprocess.run(
        [
            "edr", "monitor",
            "--slack-token", slack_token,
            "--slack-channel-name", slack_channel,
            "--profiles-dir", "/path/to/profiles",
            "--suppression-interval", "4",
        ],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        context.log.error(f"Elementary monitor failed: {result.stderr}")
        raise Exception(f"edr monitor failed: {result.stderr}")

    context.log.info(f"Elementary alerts sent: {result.stdout}")
```

### Sensor for Elementary Test Failures

```python
# sensors.py - React to Elementary test failures
from dagster import sensor, RunRequest, SensorEvaluationContext
import snowflake.connector

@sensor(
    description="Monitor Elementary test results for critical failures",
    minimum_interval_seconds=300,
)
def elementary_failure_sensor(context: SensorEvaluationContext):
    """Check for new critical test failures and trigger remediation."""
    conn = snowflake.connector.connect(
        account=..., user=..., password=...,
        database="analytics", schema="elementary",
    )
    cursor = conn.cursor()
    cursor.execute("""
        SELECT test_name, model_unique_id, status, detected_at
        FROM elementary_test_results
        WHERE status = 'fail'
          AND detected_at > %(last_check)s
          AND test_name IN ('volume_anomalies', 'freshness_anomalies')
        ORDER BY detected_at DESC
    """, {"last_check": context.cursor or "2024-01-01"})

    failures = cursor.fetchall()
    conn.close()

    if failures:
        context.update_cursor(str(failures[0][3]))
        yield RunRequest(
            run_key=f"elementary-failure-{failures[0][3]}",
            run_config={"ops": {"remediation": {"config": {
                "failures": [{"test": f[0], "model": f[1]} for f in failures]
            }}}},
        )
```

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| `dagster-dbt` | `>= 0.20.0` | Required for dbt asset integration |
| `elementary-data` | `>= 0.22.0` | Install in Dagster environment |
| Profile path | `/path/to/profiles` | Must be accessible to Dagster |
| Elementary schema | Same warehouse | Dagster reads Elementary tables |

## Pipeline Architecture

```
Dagster Schedule (daily)
  |
  +-- @dbt_assets (dbt build)
  |     |-- dbt run --select elementary  (metadata models)
  |     |-- dbt test                     (Elementary tests)
  |
  +-- elementary_report (depends on dbt_assets)
  |     |-- edr report
  |
  +-- elementary_alerts (depends on dbt_assets)
        |-- edr monitor --slack-token ...
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Run edr before dbt test completes | Use Dagster deps to sequence correctly |
| Hardcode Slack tokens in code | Use `EnvVar` or Dagster secrets |
| Skip Elementary models in dbt build | Ensure `elementary` package is included |
| Poll warehouse too frequently in sensors | Use `minimum_interval_seconds >= 300` |

## See Also

- [dbt-integration](../patterns/dbt-integration.md)
- [alerting-notifications](../patterns/alerting-notifications.md)
- [elementary-cli](../concepts/elementary-cli.md)
