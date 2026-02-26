# Checkpoint Actions

> **MCP Validated:** 2026-02-19

## Overview

Actions are post-validation hooks that execute after a Checkpoint runs. They integrate GX into your alerting, documentation, and monitoring infrastructure. Every Checkpoint can have multiple Actions that fire on every run.

## Built-in Actions

### UpdateDataDocsAction

Rebuilds the Data Docs HTML site with latest validation results:

```python
from great_expectations.checkpoint.actions import UpdateDataDocsAction

action = UpdateDataDocsAction(name="update_docs")
```

### SlackNotificationAction

Sends a Slack message via webhook:

```python
from great_expectations.checkpoint.actions import SlackNotificationAction

action = SlackNotificationAction(
    name="slack_alert",
    slack_webhook="${SLACK_WEBHOOK_URL}",
    notify_on="failure",          # "all", "failure", "success"
    show_failed_expectations=True,
)
```

### EmailAction

Sends email notifications:

```python
from great_expectations.checkpoint.actions import EmailAction

action = EmailAction(
    name="email_alert",
    smtp_address="smtp.gmail.com",
    smtp_port=587,
    sender_login="${EMAIL_USER}",
    sender_password="${EMAIL_PASSWORD}",
    sender_alias="GX Alerts",
    receiver_emails="data-team@company.com",
    notify_on="failure",
    use_tls=True,
)
```

### MicrosoftTeamsNotificationAction

```python
from great_expectations.checkpoint.actions import MicrosoftTeamsNotificationAction

action = MicrosoftTeamsNotificationAction(
    name="teams_alert",
    teams_webhook="${TEAMS_WEBHOOK_URL}",
    notify_on="failure",
)
```

## Combining Multiple Actions

```python
checkpoint = context.checkpoints.add(
    gx.Checkpoint(
        name="production_checkpoint",
        validation_definitions=[orders_vd, customers_vd],
        actions=[
            UpdateDataDocsAction(name="docs"),
            SlackNotificationAction(
                name="slack",
                slack_webhook="${SLACK_WEBHOOK}",
                notify_on="failure",
                show_failed_expectations=True,
            ),
            EmailAction(
                name="email",
                smtp_address="smtp.company.com",
                smtp_port=587,
                sender_login="${EMAIL_USER}",
                sender_password="${EMAIL_PASS}",
                receiver_emails="data-team@company.com",
                notify_on="failure",
                use_tls=True,
            ),
        ],
    )
)
```

## Custom Actions

Create custom actions by subclassing `ValidationAction`:

```python
from great_expectations.checkpoint.actions import ValidationAction

class PagerDutyAction(ValidationAction):
    def __init__(self, name: str, routing_key: str, **kwargs):
        super().__init__(name=name, **kwargs)
        self.routing_key = routing_key

    def _run(self, validation_result_suite, validation_result_suite_identifier, **kwargs):
        if not validation_result_suite.success:
            # Send PagerDuty alert
            import requests
            requests.post(
                "https://events.pagerduty.com/v2/enqueue",
                json={
                    "routing_key": self.routing_key,
                    "event_action": "trigger",
                    "payload": {
                        "summary": f"GX validation failed: {validation_result_suite_identifier}",
                        "severity": "critical",
                        "source": "great_expectations",
                    },
                },
            )
        return {"pagerduty_alert_sent": not validation_result_suite.success}
```

## Action Configuration Reference

### `notify_on` Parameter

| Value | Behavior |
|-------|----------|
| `"all"` | Fire on every validation run |
| `"failure"` | Fire only when validation fails |
| `"success"` | Fire only when validation succeeds |

### Environment Variable Substitution

All action parameters support `${VAR_NAME}` syntax for secrets:

```python
SlackNotificationAction(
    name="slack",
    slack_webhook="${GX_SLACK_WEBHOOK}",  # Resolved from env
    notify_on="failure",
)
```

## Production Pattern: Quality Gate with Alerting

```python
checkpoint = context.checkpoints.add(
    gx.Checkpoint(
        name="nightly_gate",
        validation_definitions=[bronze_vd, silver_vd, gold_vd],
        actions=[
            UpdateDataDocsAction(name="docs"),
            SlackNotificationAction(
                name="slack", slack_webhook="${SLACK_WEBHOOK}", notify_on="failure"
            ),
        ],
        result_format="SUMMARY",
    )
)

result = checkpoint.run()
if not result.success:
    raise RuntimeError(f"Quality gate failed: {result.describe()}")
```

## See Also

- [../concepts/checkpoints.md](../concepts/checkpoints.md) - Checkpoint fundamentals
- [../concepts/data-docs.md](../concepts/data-docs.md) - Data Docs generation
- [pipeline-integration.md](pipeline-integration.md) - Using checkpoints in orchestrators
