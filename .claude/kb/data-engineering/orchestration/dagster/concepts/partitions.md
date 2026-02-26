# Partitions

> **Purpose**: Data segmentation for efficient processing and backfills
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Partitions segment data into discrete units that can be processed independently. They enable incremental processing, parallel execution, and targeted backfills. Dagster supports time-based, static, dynamic, and multi-dimensional partitions.

## The Pattern

```python
import dagster as dg
import pandas as pd

daily_partitions = dg.DailyPartitionsDefinition(start_date="2024-01-01")

@dg.asset(partitions_def=daily_partitions)
def daily_events(context: dg.AssetExecutionContext) -> pd.DataFrame:
    partition_date = context.partition_key
    return load_events_for_date(partition_date)

@dg.asset(partitions_def=daily_partitions)
def daily_summary(context, daily_events: pd.DataFrame) -> pd.DataFrame:
    return daily_events.groupby("event_type").agg(count=("event_id", "count"))
```

## Quick Reference

| Partition Type | Use Case | Example |
|----------------|----------|---------|
| `DailyPartitionsDefinition` | Daily processing | ETL jobs |
| `HourlyPartitionsDefinition` | Streaming aggregation | Real-time dashboards |
| `StaticPartitionsDefinition` | Fixed categories | Regions, products |
| `DynamicPartitionsDefinition` | Runtime keys | New customers |
| `MultiPartitionsDefinition` | Multiple dimensions | Date + region |

## Static Partitions

```python
region_partitions = dg.StaticPartitionsDefinition(["us", "eu", "apac"])

@dg.asset(partitions_def=region_partitions)
def regional_sales(context: dg.AssetExecutionContext) -> pd.DataFrame:
    return load_sales_for_region(context.partition_key)
```

## Dynamic Partitions

```python
customer_partitions = dg.DynamicPartitionsDefinition(name="customers")

@dg.sensor(target="customer_data")
def new_customer_sensor(context: dg.SensorEvaluationContext):
    for customer_id in fetch_new_customers():
        yield dg.AddDynamicPartitionsRequest(
            partitions_def_name="customers", partition_keys=[customer_id]
        )
        yield dg.RunRequest(partition_key=customer_id, run_key=f"customer-{customer_id}")
```

## Multi-Dimensional Partitions

```python
multi_partitions = dg.MultiPartitionsDefinition({
    "date": dg.DailyPartitionsDefinition(start_date="2024-01-01"),
    "region": dg.StaticPartitionsDefinition(["us", "eu", "apac"]),
})

@dg.asset(partitions_def=multi_partitions)
def regional_daily_sales(context: dg.AssetExecutionContext) -> pd.DataFrame:
    keys = context.partition_key.keys_by_dimension
    return load_sales(date=keys["date"], region=keys["region"])
```

## Common Mistakes

### Wrong

```python
@dg.asset(partitions_def=daily_partitions)
def bad_asset(context):
    return load_all_data()  # Ignores partition!
```

### Correct

```python
@dg.asset(partitions_def=daily_partitions)
def good_asset(context: dg.AssetExecutionContext):
    return load_data_for_date(context.partition_key)
```

## Related

- [schedules-sensors](../concepts/schedules-sensors.md)
- [software-defined-assets](../concepts/software-defined-assets.md)
- [testing-assets](../patterns/testing-assets.md)
