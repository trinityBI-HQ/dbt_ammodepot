# Testing Assets Pattern

> **Purpose**: Unit testing assets with mocked resources for reliable pipelines
> **MCP Validated**: 2026-02-19

## When to Use

- Validating asset transformation logic
- Testing with mock data instead of production
- CI/CD pipeline testing
- Preventing regressions in data logic

## Implementation

```python
import dagster as dg
import pandas as pd
from unittest.mock import MagicMock

@dg.asset
def cleaned_orders(raw_orders: pd.DataFrame) -> pd.DataFrame:
    df = raw_orders.dropna(subset=["order_id"])
    df = df[df["amount"] > 0]
    return df

# --- Test File: test_assets.py ---
def test_cleaned_orders_removes_nulls():
    input_df = pd.DataFrame({
        "order_id": [1, None, 3],
        "amount": [100, 200, 300],
    })
    result = cleaned_orders(input_df)
    assert len(result) == 2
    assert result["order_id"].isna().sum() == 0

def test_cleaned_orders_removes_negative_amounts():
    input_df = pd.DataFrame({
        "order_id": [1, 2, 3],
        "amount": [100, -50, 300],
    })
    result = cleaned_orders(input_df)
    assert len(result) == 2
```

## Configuration

| Testing Approach | Use Case | Complexity |
|------------------|----------|------------|
| Direct function call | Pure transformation logic | Low |
| `materialize()` | Full asset with IO | Medium |
| Mock resources | External service testing | Medium |

## Mocking Resources

```python
from unittest.mock import MagicMock

@dg.asset
def customer_metrics(warehouse: WarehouseResource) -> pd.DataFrame:
    return warehouse.query("SELECT * FROM customers")

def test_customer_metrics_with_mock():
    mock_warehouse = MagicMock()
    mock_warehouse.query.return_value = pd.DataFrame({
        "customer_id": [1, 2], "name": ["Alice", "Bob"],
    })
    result = customer_metrics(mock_warehouse)
    assert len(result) == 2
```

## Testing with materialize()

```python
from dagster import materialize

def test_asset_materialization():
    class InMemoryIOManager(dg.IOManager):
        def __init__(self):
            self.values = {}
        def handle_output(self, context, obj):
            self.values[context.asset_key] = obj
        def load_input(self, context):
            return self.values[context.asset_key]

    result = materialize(
        assets=[raw_orders, cleaned_orders],
        resources={"io_manager": InMemoryIOManager(), "warehouse": mock_warehouse},
    )
    assert result.success
```

## Asset Checks

```python
@dg.asset_check(asset=cleaned_orders)
def orders_not_empty(cleaned_orders: pd.DataFrame) -> dg.AssetCheckResult:
    return dg.AssetCheckResult(
        passed=len(cleaned_orders) > 0,
        metadata={"row_count": len(cleaned_orders)},
    )

@dg.asset_check(asset=cleaned_orders)
def no_duplicate_orders(cleaned_orders: pd.DataFrame) -> dg.AssetCheckResult:
    duplicates = cleaned_orders["order_id"].duplicated().sum()
    return dg.AssetCheckResult(passed=duplicates == 0)
```

## Example Usage

```bash
pytest tests/test_assets.py -v
dagster asset check --select cleaned_orders
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Test entire jobs | Test individual assets |
| Use production data | Mock data or fixtures |
| Skip resource mocking | Always mock external services |
| Test only happy path | Include edge cases |

## See Also

- [software-defined-assets](../concepts/software-defined-assets.md)
- [resources](../concepts/resources.md)
- [io-managers](../concepts/io-managers.md)
