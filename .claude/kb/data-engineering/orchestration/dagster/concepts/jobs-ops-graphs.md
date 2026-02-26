# Jobs, Ops, and Graphs

> **Purpose**: Imperative pipeline building blocks for complex orchestration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Ops are computational units of work that can be assembled into graphs. Graphs connect ops to form DAGs, and jobs bind graphs to resources for execution. While assets are the recommended approach for new pipelines, ops and graphs remain useful for complex imperative logic, legacy migrations, and cases where task-centric thinking fits better.

## The Pattern

```python
import dagster as dg

@dg.op
def extract_data(context: dg.OpExecutionContext) -> dict:
    context.log.info("Extracting data...")
    return {"records": [1, 2, 3, 4, 5]}

@dg.op
def transform_data(context: dg.OpExecutionContext, data: dict) -> dict:
    return {"records": [r * 2 for r in data["records"]]}

@dg.op
def load_data(context: dg.OpExecutionContext, data: dict) -> None:
    context.log.info(f"Loading {len(data['records'])} records")

@dg.job
def etl_pipeline():
    load_data(transform_data(extract_data()))

defs = dg.Definitions(jobs=[etl_pipeline])
```

## Quick Reference

| Concept | Purpose | Decorator |
|---------|---------|-----------|
| Op | Single unit of computation | `@op` |
| Graph | DAG of ops | `@graph` |
| Job | Executable graph with resources | `@job` |

## Graph Pattern

```python
@dg.op
def add_one(x: int) -> int:
    return x + 1

@dg.op
def multiply_two(x: int) -> int:
    return x * 2

@dg.graph
def math_graph(start: int) -> int:
    return multiply_two(add_one(start))

@dg.job
def math_job():
    math_graph()
```

## Graph-Backed Assets

```python
@dg.op
def fetch_api_data() -> dict:
    return {"value": 42}

@dg.op
def transform_api_data(data: dict) -> int:
    return data["value"] * 2

@dg.graph_asset
def api_derived_metric():
    """Asset backed by a graph of ops."""
    return transform_api_data(fetch_api_data())
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Using ops for simple data pipelines
@dg.op
def load_orders():
    return pd.read_csv("orders.csv")

@dg.job
def orders_pipeline():
    transform_orders(load_orders())
```

### Correct

```python
# Correct: Use assets for data pipelines
@dg.asset
def raw_orders() -> pd.DataFrame:
    return pd.read_csv("orders.csv")

@dg.asset
def daily_orders(raw_orders: pd.DataFrame) -> pd.DataFrame:
    return raw_orders.groupby("date").sum()
```

## Job-Less Pattern (v1.9+)

Schedules and sensors no longer require wrapping assets in a job. You can target assets directly via `AssetSelection`, making jobs optional for most use cases. Jobs remain useful for complex imperative workflows.

## When to Use Ops vs Assets

| Use Ops/Graphs When | Use Assets When |
|---------------------|-----------------|
| Complex control flow | Data transformation |
| Side effects (notifications) | Building data products |
| Legacy pipeline migration | Lineage tracking needed |
| Task-centric mental model | Asset-centric mental model |

## Related

- [software-defined-assets](../concepts/software-defined-assets.md)
- [definitions](../concepts/definitions.md)
- [schedules-sensors](../concepts/schedules-sensors.md)
