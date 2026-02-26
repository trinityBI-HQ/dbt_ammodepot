# Pipeline Integration

> **MCP Validated:** 2026-02-19

## Overview

Great Expectations integrates with data orchestrators to serve as a quality gate within pipelines. This pattern covers integration with Dagster, Airflow, and dbt.

## Dagster Integration

### Using Asset Checks

Dagster's `@asset_check` decorator is the recommended way to run GX validations as part of your asset graph:

```python
import great_expectations as gx
import pandas as pd
from dagster import asset, asset_check, AssetCheckResult, AssetCheckSeverity

@asset
def orders() -> pd.DataFrame:
    return pd.read_parquet("s3://data-lake/orders.parquet")

@asset_check(asset=orders, blocking=True)
def orders_quality_check(orders: pd.DataFrame) -> AssetCheckResult:
    context = gx.get_context()

    data_source = context.data_sources.add_pandas(name="dagster_source")
    data_asset = data_source.add_dataframe_asset(name="orders_asset")
    batch_def = data_asset.add_batch_definition_whole_dataframe("batch")

    suite = context.suites.add(gx.ExpectationSuite(name="orders_suite"))
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
    )
    suite.add_expectation(
        gx.expectations.ExpectTableRowCountToBeBetween(min_value=1)
    )

    validation_def = context.validation_definitions.add(
        gx.ValidationDefinition(
            name="orders_validation", data=batch_def, suite=suite
        )
    )

    result = validation_def.run(batch_parameters={"dataframe": orders})

    return AssetCheckResult(
        passed=result.success,
        severity=AssetCheckSeverity.ERROR,
        metadata={"expectations_evaluated": len(result.results)},
    )
```

### Reusable GX Resource

```python
from dagster import ConfigurableResource

class GXValidationResource(ConfigurableResource):
    def validate_dataframe(
        self, df: pd.DataFrame, expectations: list
    ) -> bool:
        context = gx.get_context()
        source = context.data_sources.add_pandas(name="resource_source")
        asset = source.add_dataframe_asset(name="asset")
        batch_def = asset.add_batch_definition_whole_dataframe("batch")

        suite = context.suites.add(gx.ExpectationSuite(name="suite"))
        for exp in expectations:
            suite.add_expectation(exp)

        vd = context.validation_definitions.add(
            gx.ValidationDefinition(name="vd", data=batch_def, suite=suite)
        )
        result = vd.run(batch_parameters={"dataframe": df})
        return result.success
```

## Airflow Integration

### PythonOperator Approach

```python
from airflow.decorators import task

@task
def validate_orders():
    import great_expectations as gx

    context = gx.get_context(mode="file", project_root_dir="/opt/gx")
    checkpoint = context.checkpoints.get("orders_checkpoint")
    result = checkpoint.run()

    if not result.success:
        raise ValueError("Data quality check failed")
```

### As a Quality Gate Between Tasks

```python
from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator

def run_quality_check(**kwargs):
    context = gx.get_context(mode="file", project_root_dir="/opt/gx")
    result = context.checkpoints.get("orders_checkpoint").run()
    return "proceed_task" if result.success else "alert_task"

with DAG("orders_pipeline", schedule="@daily") as dag:
    ingest = PythonOperator(task_id="ingest", python_callable=ingest_data)
    quality_gate = BranchPythonOperator(
        task_id="quality_gate", python_callable=run_quality_check
    )
    proceed = PythonOperator(task_id="proceed_task", python_callable=transform)
    alert = PythonOperator(task_id="alert_task", python_callable=send_alert)

    ingest >> quality_gate >> [proceed, alert]
```

## dbt Integration

### Post-Run Validation

Run GX after dbt to validate model outputs:

```python
import subprocess
import great_expectations as gx

# 1. Run dbt
subprocess.run(["dbt", "run", "--select", "orders"], check=True)

# 2. Validate dbt output with GX
context = gx.get_context()
source = context.data_sources.add_postgres(
    name="warehouse", connection_string="${DWH_CONNECTION}"
)
asset = source.add_table_asset(name="orders", table_name="analytics.orders")
batch_def = asset.add_batch_definition_whole_table("full")

suite = context.suites.add(gx.ExpectationSuite(name="dbt_orders_suite"))
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
)

vd = context.validation_definitions.add(
    gx.ValidationDefinition(name="dbt_orders_vd", data=batch_def, suite=suite)
)
result = vd.run()
assert result.success, "dbt model output failed quality checks"
```

## Best Practices

| Practice | Rationale |
|----------|-----------|
| Use `blocking=True` in Dagster checks | Prevents downstream assets from materializing on failure |
| Store GX context in persistent mode for Airflow | Preserves suites across DAG runs |
| Separate schema checks from business rules | Run schema checks early, business rules after transforms |
| Use `mostly` for soft thresholds | Avoid false failures on acceptable data variance |
| Log validation metadata | Attach expectation counts and results to orchestrator metadata |

## See Also

- [../concepts/checkpoints.md](../concepts/checkpoints.md) - Checkpoint configuration
- [checkpoint-actions.md](checkpoint-actions.md) - Actions for alerting on failures
