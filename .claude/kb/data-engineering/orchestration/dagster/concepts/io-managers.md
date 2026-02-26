# IO Managers

> **Purpose**: Storage abstraction for asset inputs and outputs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

IO managers handle where data is stored and loaded between assets. They eliminate boilerplate code for reading and writing data, and enable seamless environment switching (local files in dev, cloud storage in production). IO managers implement two methods: `handle_output` for storing data and `load_input` for retrieving it.

## The Pattern

```python
import dagster as dg
from dagster import ConfigurableIOManager, InputContext, OutputContext
import pandas as pd
from pathlib import Path

class ParquetIOManager(ConfigurableIOManager):
    """IO Manager that stores DataFrames as Parquet files."""
    base_path: str

    def _get_path(self, context) -> Path:
        asset_key = context.asset_key.path
        return Path(self.base_path) / "/".join(asset_key) / "data.parquet"

    def handle_output(self, context: OutputContext, obj: pd.DataFrame):
        path = self._get_path(context)
        path.parent.mkdir(parents=True, exist_ok=True)
        obj.to_parquet(path)

    def load_input(self, context: InputContext) -> pd.DataFrame:
        return pd.read_parquet(self._get_path(context))

@dg.asset
def raw_data() -> pd.DataFrame:
    return pd.DataFrame({"a": [1, 2, 3]})

defs = dg.Definitions(
    assets=[raw_data],
    resources={"io_manager": ParquetIOManager(base_path="/data/warehouse")},
)
```

## Quick Reference

| Method | Called When | Returns |
|--------|-------------|---------|
| `handle_output` | Asset produces output | None |
| `load_input` | Downstream asset needs input | The loaded data |

## Built-in IO Managers

```python
from dagster_aws.s3 import S3PickleIOManager
from dagster_gcp.bigquery import BigQueryPandasIOManager

defs = dg.Definitions(
    resources={
        "io_manager": S3PickleIOManager(s3_bucket="my-bucket", s3_prefix="dagster"),
        "warehouse_io": BigQueryPandasIOManager(
            project=dg.EnvVar("GCP_PROJECT"), dataset="analytics"
        ),
    },
)
```

## Multiple IO Managers

```python
@dg.asset(io_manager_key="warehouse_io")
def fact_orders() -> pd.DataFrame:
    """Stored in BigQuery via warehouse_io."""
    return load_orders()

@dg.asset  # Uses default io_manager
def temp_processing() -> pd.DataFrame:
    return process_temp_data()
```

## When to Use IO Managers vs Resources

| Use IO Manager When | Use Resource When |
|---------------------|-------------------|
| Multiple assets share storage pattern | One-off data operations |
| Need automatic input/output handling | Custom query logic |
| Want to swap storage between environments | API calls, notifications |

## Common Mistakes

### Wrong

```python
@dg.asset
def my_asset():
    data = process()
    data.to_parquet("/path/to/output.parquet")  # Boilerplate!
    return data
```

### Correct

```python
@dg.asset
def my_asset() -> pd.DataFrame:
    return process()  # IO manager stores automatically
```

## Testing with Mock IO Manager

```python
class InMemoryIOManager(dg.IOManager):
    def __init__(self):
        self.values = {}
    def handle_output(self, context, obj):
        self.values[context.asset_key] = obj
    def load_input(self, context):
        return self.values[context.asset_key]
```

## Related

- [resources](../concepts/resources.md)
- [testing-assets](../patterns/testing-assets.md)
- [cloud-integrations](../patterns/cloud-integrations.md)
