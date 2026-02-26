# Expectations

> **MCP Validated:** 2026-02-19

## What Is an Expectation?

An Expectation is a verifiable assertion about data quality. Each Expectation tests a specific property of your data — such as whether a column contains null values, whether values fall within a range, or whether row counts meet a threshold.

In GX 1.x, Expectations are Python objects created via `gx.expectations.*`.

## Creating Expectations

```python
import great_expectations as gx

# Add to an Expectation Suite
suite = context.suites.add(gx.ExpectationSuite(name="orders_suite"))

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="amount", min_value=0, max_value=100000
    )
)
```

## Common Expectations

### Column Value Expectations

| Expectation | Description |
|-------------|-------------|
| `ExpectColumnValuesToNotBeNull` | No null values |
| `ExpectColumnValuesToBeUnique` | All values unique |
| `ExpectColumnValuesToBeInSet` | Values from allowed list |
| `ExpectColumnValuesToNotBeInSet` | Values NOT in disallowed list |
| `ExpectColumnValuesToMatchRegex` | Values match regex pattern |
| `ExpectColumnValuesToBeOfType` | Column has expected data type |
| `ExpectColumnValuesToBeBetween` | Numeric values in range |
| `ExpectColumnValueLengthsToBeBetween` | String lengths in range |

### Aggregate Expectations

| Expectation | Description |
|-------------|-------------|
| `ExpectTableRowCountToBeBetween` | Row count in range |
| `ExpectTableRowCountToEqual` | Exact row count |
| `ExpectColumnMeanToBeBetween` | Mean value in range |
| `ExpectColumnMaxToBeBetween` | Max value in range |
| `ExpectColumnMinToBeBetween` | Min value in range |
| `ExpectColumnMedianToBeBetween` | Median in range |
| `ExpectColumnStdevToBeBetween` | Standard deviation in range |
| `ExpectColumnDistinctValuesToBeInSet` | Distinct values match set |
| `ExpectColumnProportionOfUniqueValuesToBeBetween` | Uniqueness ratio |

### Multi-Column / Table Expectations

| Expectation | Description |
|-------------|-------------|
| `ExpectColumnPairValuesToBeEqual` | Two columns match |
| `ExpectCompoundColumnsToBeUnique` | Multi-column uniqueness |
| `ExpectTableColumnsToMatchOrderedList` | Schema column order |

## Common Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `column` | str | Target column name |
| `mostly` | float | Fraction that must pass (0.0–1.0), default 1.0 |
| `severity` | str | `"critical"`, `"warning"`, or `"info"` |
| `meta` | dict | User metadata attached to the Expectation |

### The `mostly` Parameter

Use `mostly` for fuzzy matching on real-world data:

```python
# Allow up to 5% nulls
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="email", mostly=0.95
    )
)
```

### Severity Levels

```python
# Critical: blocks pipeline
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="id", severity="critical"
    )
)
# Warning: logged but doesn't block
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="age", min_value=0, max_value=150, severity="warning"
    )
)
```

## Validating Inline (Without Checkpoints)

```python
batch = batch_definition.get_batch()
result = batch.validate(gx.expectations.ExpectColumnValuesToNotBeNull(column="id"))
print(result.success)  # True or False
```

## Custom SQL Expectations

Subclass `UnexpectedRowsExpectation` for SQL-based custom checks:

```python
import great_expectations.expectations as gxe

class ExpectNoOrphanedOrders(gxe.UnexpectedRowsExpectation):
    description = "All orders reference a valid customer"
    unexpected_rows_query = """
        SELECT * FROM {batch}
        WHERE customer_id NOT IN (SELECT id FROM customers)
    """
```

## ExpectAI (GX Cloud)

As of Feb 2025, GX Cloud includes **ExpectAI** -- an AI-driven Expectation generator. Describe quality rules in plain English (Jul 2025 enhancement) and ExpectAI creates the corresponding Expectation objects. Enhanced SQL Expectations (Aug 2025) add inline SQL prompts with draft-before-save in the Cloud UI.

## See Also

- [expectation-suites.md](expectation-suites.md) - Grouping Expectations
- [../patterns/custom-expectations.md](../patterns/custom-expectations.md) - Building custom Expectations
