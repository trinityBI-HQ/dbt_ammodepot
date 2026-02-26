# Alerting and Notifications Pattern

> **Purpose**: Setting up Slack, Teams, email, and PagerDuty alerts for Elementary test failures
> **MCP Validated**: 2026-02-19

## When to Use

- Need proactive notification of data quality issues
- Want to route alerts to specific channels based on severity or ownership
- Setting up automated alerting in CI/CD pipelines
- Integrating data quality alerts with incident management (PagerDuty)

## Implementation

### Slack via Webhook (Simplest)

```yaml
# ~/.edr/config.yml
slack:
  notification_webhook: "https://hooks.slack.com/services/T00/B00/xxx"
  group_alerts_by: "table"   # Groups related alerts together
```

```bash
# Send alerts after running tests
dbt test
edr monitor
```

### Slack via Token + Channel

```yaml
# ~/.edr/config.yml
slack:
  token: "xoxb-your-slack-bot-token"
  channel_name: "data-quality-alerts"
  group_alerts_by: "table"
  timezone: "US/Eastern"
```

```bash
# Or pass directly via CLI
edr monitor -st xoxb-your-token -ch data-quality-alerts
```

### Microsoft Teams

```yaml
# ~/.edr/config.yml
teams:
  notification_webhook: "https://outlook.office.com/webhook/xxx"
  group_alerts_by: "table"
```

```bash
edr monitor
```

### Multi-Channel Routing

```yaml
# ~/.edr/config.yml
slack:
  token: "xoxb-your-slack-bot-token"
  channel_name: "data-alerts-general"
  group_alerts_by: "table"
  timezone: "US/Eastern"

# Use selectors to route different alerts to different channels
# Run separate monitor commands per channel
```

```bash
# Critical alerts to #data-incidents
edr monitor -st xoxb-token -ch data-incidents --select tag:critical

# Standard alerts to #data-quality
edr monitor -st xoxb-token -ch data-quality --select tag:standard
```

### Report Distribution

```bash
# Send HTML report to Slack channel
edr send-report -st xoxb-token -ch data-reports

# Upload report to S3
edr send-report --s3-endpoint-url s3://my-bucket/elementary-reports/

# Upload report to GCS
edr send-report --gcs-bucket-name my-reports-bucket --gcs-prefix elementary/
```

## Configuration

| Setting | Values | Description |
|---------|--------|-------------|
| `slack.token` | Bot token | Slack API bot token (xoxb-...) |
| `slack.channel_name` | Channel name | Target Slack channel |
| `slack.notification_webhook` | Webhook URL | Slack incoming webhook URL |
| `slack.group_alerts_by` | `table` or `alert` | How to group notifications |
| `slack.timezone` | TZ string | Timezone for alert timestamps |
| `teams.notification_webhook` | Webhook URL | Teams incoming webhook |
| `suppression_interval` | Integer (hours) | Suppress duplicate alerts |

## CI/CD Integration

### GitHub Actions

```yaml
name: dbt Test + Elementary Alerts
on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM

jobs:
  dbt-elementary:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          pip install dbt-snowflake
          pip install 'elementary-data[snowflake]'

      - name: Run dbt
        run: |
          dbt deps
          dbt run --select elementary
          dbt build

      - name: Send Elementary alerts
        env:
          EDR_MONITOR_SLACK_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          EDR_MONITOR_SLACK_CHANNEL_NAME: "data-quality-alerts"
        run: edr monitor

      - name: Upload report to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: edr send-report --s3-endpoint-url s3://reports-bucket/elementary/
```

### Environment Variable Format

```bash
# All edr options available as environment variables
EDR_MONITOR_SLACK_TOKEN="xoxb-your-token"
EDR_MONITOR_SLACK_CHANNEL_NAME="data-alerts"
EDR_MONITOR_DAYS_BACK=3
EDR_MONITOR_SUPPRESSION_INTERVAL=4
EDR_REPORT_FILE_PATH="/reports"
EDR_REPORT_TIMEZONE="US/Eastern"
```

## Alert Grouping

| Mode | Behavior |
|------|----------|
| `group_alerts_by: table` | All alerts for the same table in one message (recommended) |
| `group_alerts_by: alert` | Each alert as a separate message |

## Suppression

Use `--suppression-interval` to prevent duplicate alerts within a time window:

```bash
# Suppress duplicate alerts for 4 hours
edr monitor --suppression-interval 4
```

## Example Usage

```bash
# Full workflow: test, alert, report
dbt test
edr monitor -st xoxb-token -ch data-alerts --suppression-interval 4
edr send-report -st xoxb-token -ch data-reports
```

## See Also

- [elementary-cli](../concepts/elementary-cli.md)
- [dbt-integration](../patterns/dbt-integration.md)
- [elementary-cloud](../concepts/elementary-cloud.md)
