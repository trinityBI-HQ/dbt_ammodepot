# Custom Expectations

> **MCP Validated:** 2026-02-19

## Overview

When built-in Expectations don't cover your validation needs, GX allows you to create custom Expectations. The most common approach in GX 1.x is subclassing `UnexpectedRowsExpectation` for SQL-based checks, or creating column-level custom Expectations.

## Custom SQL Expectations

### UnexpectedRowsExpectation

The simplest way to create custom Expectations. Write a SQL query that returns "unexpected" rows — rows that violate your rule. If the query returns zero rows, the Expectation passes.

```python
import great_expectations.expectations as gxe

class ExpectNoNegativeRevenue(gxe.UnexpectedRowsExpectation):
    """Revenue should never be negative."""
    description = "All revenue values are non-negative"
    unexpected_rows_query = """
        SELECT *
        FROM {batch}
        WHERE revenue < 0
    """

# Use it
batch = batch_definition.get_batch()
result = batch.validate(ExpectNoNegativeRevenue())
```

### Parameterized SQL Expectations

```python
class ExpectTransferTimeUnderThreshold(gxe.UnexpectedRowsExpectation):
    """Transfers should complete within a threshold."""
    max_seconds: int = 60
    description = "Transfers complete within threshold"
    unexpected_rows_query = """
        SELECT *
        FROM {batch}
        WHERE EXTRACT(EPOCH FROM (completed_at - started_at)) > {max_seconds}
    """

# Use with custom threshold
result = batch.validate(ExpectTransferTimeUnderThreshold(max_seconds=45))
```

### Referential Integrity Check

```python
class ExpectAllOrdersHaveCustomer(gxe.UnexpectedRowsExpectation):
    """Every order must reference a valid customer."""
    description = "No orphaned orders"
    unexpected_rows_query = """
        SELECT *
        FROM {batch}
        WHERE customer_id NOT IN (SELECT id FROM customers)
    """
```

### Freshness Check

```python
class ExpectDataFresherThanHours(gxe.UnexpectedRowsExpectation):
    """Data should be updated within N hours."""
    max_hours: int = 24
    description = "Data is fresh"
    unexpected_rows_query = """
        SELECT *
        FROM {batch}
        WHERE updated_at < NOW() - INTERVAL '{max_hours} hours'
    """
```

## Column-Level Custom Expectations

For custom logic on column values (works with Pandas and Spark):

```python
from great_expectations.expectations import Expectation
from great_expectations.core.expectation_configuration import ExpectationConfiguration

class ExpectColumnValuesToBeValidEmail(Expectation):
    """Validates that column values are properly formatted emails."""
    expectation_type = "expect_column_values_to_be_valid_email"

    # Map to a built-in expectation with custom regex
    map_metric = "column_values.match_regex"
    success_keys = ("column", "regex", "mostly")
    default_kwarg_values = {
        "regex": r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
        "mostly": 1.0,
    }
```

## Organizing Custom Expectations

### Plugin Directory

Place custom Expectations in your GX project's `plugins/` directory:

```
gx_project/
└── gx/
    └── plugins/
        └── expectations/
            ├── __init__.py
            ├── expect_no_negative_revenue.py
            └── expect_data_freshness.py
```

GX automatically discovers custom Expectations in the plugins directory.

### As a Shared Package

For team-wide reuse, package custom Expectations:

```python
# my_gx_expectations/expectations.py
import great_expectations.expectations as gxe

class ExpectNoDuplicateKeys(gxe.UnexpectedRowsExpectation):
    """Primary key column should have no duplicates."""
    key_column: str = "id"
    description = "No duplicate keys"
    unexpected_rows_query = """
        SELECT {key_column}, COUNT(*) as cnt
        FROM {batch}
        GROUP BY {key_column}
        HAVING COUNT(*) > 1
    """
```

## Using Custom Expectations in Suites

```python
suite = context.suites.add(gx.ExpectationSuite(name="custom_suite"))

# Custom SQL expectation
suite.add_expectation(ExpectNoNegativeRevenue())

# Custom with parameters
suite.add_expectation(
    ExpectTransferTimeUnderThreshold(max_seconds=30)
)

# Mix with built-in expectations
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="id")
)
```

## Best Practices

| Practice | Rationale |
|----------|-----------|
| Prefer `UnexpectedRowsExpectation` for SQL | Simplest custom expectation pattern |
| Use parameterized fields | Makes expectations reusable with different thresholds |
| Add `description` field | Appears in Data Docs and validation output |
| Test with known-bad data | Verify expectations actually catch violations |
| Keep queries efficient | Custom SQL runs against production databases |

## See Also

- [../concepts/expectations.md](../concepts/expectations.md) - Built-in Expectations
- [../concepts/expectation-suites.md](../concepts/expectation-suites.md) - Grouping custom expectations
- [pipeline-integration.md](pipeline-integration.md) - Running custom checks in pipelines
