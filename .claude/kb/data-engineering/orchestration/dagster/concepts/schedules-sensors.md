# Schedules and Sensors

> **Purpose**: Automated execution triggers — cron schedules and event-driven sensors
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Schedules trigger runs at cron intervals. Sensors react to external events (new files, database changes, API updates). Both require the Dagster daemon (included in `dagster dev`).

**v1.9+**: Schedules and sensors no longer require a job target. They can directly target assets via `AssetSelection`, making the pattern simpler.

## Schedule Pattern — Daily dbt Build

```python
from dagster import DefaultScheduleStatus, ScheduleDefinition
from .assets import theraice_dbt_assets

daily_dbt_build = ScheduleDefinition(
    name="theraice_daily_build",
    target=theraice_dbt_assets,
    cron_schedule="0 6 * * *",  # 6:00 AM UTC daily
    default_status=DefaultScheduleStatus.STOPPED,  # Enable after validation
)
```

## Job-Less Schedule (v1.9+)

```python
from dagster import AssetSelection, ScheduleDefinition

# Target assets directly without defining a job
daily_analytics = ScheduleDefinition(
    name="daily_analytics",
    cron_schedule="0 6 * * *",
    target=AssetSelection.groups("analytics"),
)
```

## Job-Less Sensor (v1.9+)

```python
@sensor(asset_selection=AssetSelection.groups("raw"))
def new_file_sensor(context):
    if check_for_new_files():
        yield RunRequest()
```

## Sensor Pattern -- Snowflake Stream CDC

```python
from dagster import AssetSelection, DefaultSensorStatus, RunRequest, SkipReason, sensor
from dagster_snowflake import SnowflakeResource

STREAMS = {
    "FIVETRAN_DATABASE.AMAZON_SELLING_PARTNER.DAGSTER_STREAM__AMAZON_SP_ORDERS": "amazon",
    "FIVETRAN_SHOPIFY.SHOPIFY.DAGSTER_STREAM__SHOPIFY_ORDERS": "shopify",
}

@sensor(name="theraice_orders_sensor", minimum_interval_seconds=300,
        default_status=DefaultSensorStatus.STOPPED,
        asset_selection=AssetSelection.assets(theraice_dbt_assets))
def orders_stream_sensor(context, snowflake: SnowflakeResource):
    triggered_sources = []
    with snowflake.get_connection() as conn:
        cursor = conn.cursor()
        for stream_fqn, source_name in STREAMS.items():
            cursor.execute(f"SELECT SYSTEM$STREAM_HAS_DATA('{stream_fqn}')")
            row = cursor.fetchone()
            if row and row[0] in (True, "true", "True"):
                triggered_sources.append(source_name)
                # Consume stream → advance offset + audit log
                cursor.execute(f"""
                    INSERT INTO THERAICE.DBT_DEV._DAGSTER_STREAM_LOG
                        (stream_name, detected_at, row_count)
                    SELECT '{stream_fqn}', CURRENT_TIMESTAMP(), COUNT(*)
                    FROM {stream_fqn}
                """)
    if not triggered_sources:
        yield SkipReason("No new order data in streams")
        return
    yield RunRequest(
        run_key=f"orders-{datetime.now(timezone.utc).isoformat()}",
        tags={"trigger": "order_stream", "sources": ",".join(sorted(triggered_sources))},
    )
```

Key design choices:
- **APPEND_ONLY streams**: Only track inserts (correct for Fivetran)
- **SYSTEM$STREAM_HAS_DATA()**: Lightweight check before consuming
- **Audit table**: `_DAGSTER_STREAM_LOG` tracks when streams were consumed
- **Dedup**: Check for active `trigger: order_stream` runs before emitting

## Cron Reference

| Expression | Meaning |
|------------|---------|
| `0 6 * * *` | 6 AM daily |
| `0 6 * * 1-5` | 6 AM weekdays |
| `0 */2 * * *` | Every 2 hours |
| `*/5 * * * *` | Every 5 minutes |

## Quick Reference

| Type | Trigger | Example |
|------|---------|---------|
| `ScheduleDefinition` | Cron | Daily dbt build |
| `@sensor` | External condition | Snowflake Stream has data |
| `@asset_sensor` | Asset materialization | Cross-pipeline dependency |

## Common Mistakes

### Wrong
```python
@sensor(target="*")
def bad_sensor():
    # No dedup — re-triggers same data on restart
    yield RunRequest(run_key="static-key")
```

### Correct
```python
@sensor(target="*")
def good_sensor(context):
    # Use unique run_key with timestamp to prevent duplicates
    yield RunRequest(run_key=f"orders-{datetime.now(timezone.utc).isoformat()}")
```

## Related

- [software-defined-assets](../concepts/software-defined-assets.md)
- [dbt-integration](../patterns/dbt-integration.md)
- [dagster-cloud](../concepts/dagster-cloud.md)
