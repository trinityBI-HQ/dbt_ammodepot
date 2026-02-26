# Software-Defined Assets

> **Purpose**: Declarative data assets that shift focus from task execution to asset production
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Software-defined assets (SDAs) represent a paradigm shift in data orchestration. Instead of defining tasks and their execution order, you declare what data assets should exist and how to compute them. Dagster automatically handles execution logic, dependency tracking, and lineage. Each asset is a piece of data defined in code, making pipelines versionable, testable, and observable.

## The Pattern

```python
import dagster as dg
import pandas as pd

@dg.asset(
    group_name="analytics",
    description="Raw orders data from source system",
)
def raw_orders() -> pd.DataFrame:
    """Load orders from source database."""
    return pd.read_csv("s3://bucket/orders.csv")

@dg.asset(
    group_name="analytics",
    description="Cleaned and validated orders",
)
def cleaned_orders(raw_orders: pd.DataFrame) -> pd.DataFrame:
    """Clean and validate order data."""
    df = raw_orders.dropna(subset=["order_id", "customer_id"])
    df["order_date"] = pd.to_datetime(df["order_date"])
    return df

@dg.asset(
    group_name="analytics",
    description="Daily order aggregations",
)
def daily_order_summary(cleaned_orders: pd.DataFrame) -> pd.DataFrame:
    """Aggregate orders by day."""
    return cleaned_orders.groupby("order_date").agg(
        total_orders=("order_id", "count"),
        total_revenue=("amount", "sum"),
    ).reset_index()

# Register all assets in Definitions
defs = dg.Definitions(assets=[raw_orders, cleaned_orders, daily_order_summary])
```

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| Function with `@asset` | `AssetsDefinition` | Dependencies inferred from args |
| `group_name="x"` | Logical grouping | Displayed in UI, useful for filtering |
| `deps=[AssetKey("x")]` | External dependency | For assets outside current module |

## Multi-Asset Pattern

```python
@dg.multi_asset(
    outs={
        "customers": dg.AssetOut(group_name="crm"),
        "orders": dg.AssetOut(group_name="sales"),
    }
)
def extract_crm_data(context: dg.AssetExecutionContext):
    """Extract multiple tables from CRM in one operation."""
    customers_df = extract_customers()
    orders_df = extract_orders()
    return customers_df, orders_df
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Using @op for new data pipelines
@dg.op
def process_data():
    # This loses lineage benefits
    data = load_data()
    return transform(data)

@dg.job
def my_pipeline():
    process_data()
```

### Correct

```python
# Correct: Use @asset for declarative pipelines
@dg.asset
def raw_data() -> pd.DataFrame:
    return load_data()

@dg.asset
def processed_data(raw_data: pd.DataFrame) -> pd.DataFrame:
    return transform(raw_data)
```

## Declarative Automation (v1.9 GA)

`AutomationCondition` replaces the deprecated `AutoMaterializePolicy`. Conditions are composable, testable, and support asset checks.

```python
@dg.asset(
    automation_condition=dg.AutomationCondition.eager(),
    description="Auto-materializes when any upstream changes",
)
def derived_metrics(cleaned_orders: pd.DataFrame) -> pd.DataFrame:
    return cleaned_orders.groupby("date").sum()

# Compose conditions
@dg.asset(
    automation_condition=(
        dg.AutomationCondition.any_deps_updated()
        & ~dg.AutomationCondition.in_progress()
    ),
)
def composed_asset(source: pd.DataFrame) -> pd.DataFrame:
    return source.head(100)
```

Built-in conditions: `eager()`, `on_cron("0 6 * * *")`, `any_deps_updated()`, `any_deps_missing()`, `in_progress()`, `on_missing()`. Combine with `&`, `|`, `~` operators.

> **Deprecated:** `AutoMaterializePolicy` -- migrate to `AutomationCondition`. `AutoMaterializePolicy.eager()` maps to `AutomationCondition.eager()`, `.lazy()` maps to `AutomationCondition.on_missing()`.

## Key Benefits

- **Automatic Lineage**: Dependencies tracked from function signatures
- **Selective Execution**: Materialize subsets of the asset graph
- **Observability**: Track failures, logs, and history per asset
- **Environment Agnostic**: Same code works in dev and production
- **Declarative Automation**: Composable `AutomationCondition` for auto-materialization

## Related

- [definitions](../concepts/definitions.md)
- [io-managers](../concepts/io-managers.md)
- [partitions](../concepts/partitions.md)
