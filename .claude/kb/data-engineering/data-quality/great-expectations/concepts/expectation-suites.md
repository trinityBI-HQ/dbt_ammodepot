# Expectation Suites

> **MCP Validated:** 2026-02-19

## What Is an Expectation Suite?

An Expectation Suite is a named collection of Expectations applied together as a group. Suites represent a coherent set of quality rules for a specific data asset — such as "all rules for the orders table" or "schema checks for raw events."

## Creating and Managing Suites

### Create a Suite

```python
import great_expectations as gx

context = gx.get_context()
suite = context.suites.add(
    gx.ExpectationSuite(name="orders_quality")
)
```

### Add Expectations to a Suite

```python
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeUnique(column="order_id")
)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="total", min_value=0, max_value=1000000
    )
)
suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(min_value=1)
)
```

### Retrieve, List, Delete

```python
# Get by name
suite = context.suites.get(name="orders_quality")

# List all suites
all_suites = context.suites.all()

# Delete
context.suites.delete(name="orders_quality")
```

## Suite Organization Patterns

### By Data Asset

One suite per table or data asset:

```
raw_orders_suite       → Schema + null checks for raw orders
clean_orders_suite     → Business rules for cleaned orders
gold_revenue_suite     → Aggregation + SLA checks for gold layer
```

### By Medallion Layer

```
bronze_ingestion_suite → Row counts, schema validation, freshness
silver_quality_suite   → Referential integrity, dedup, type checks
gold_serving_suite     → Statistical bounds, completeness, SLAs
```

### By Concern

```
schema_suite           → Column existence, types, ordering
completeness_suite     → Null checks across all required fields
business_rules_suite   → Domain-specific value constraints
```

## Validation Definitions

A Validation Definition links a Suite to a Batch Definition, specifying what data to validate against which rules:

```python
validation_def = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="validate_daily_orders",
        data=batch_definition,
        suite=suite,
    )
)
```

### Running a Validation Definition

```python
# SQL/table data
result = validation_def.run()

# DataFrame data (pass at runtime)
result = validation_def.run(batch_parameters={"dataframe": df})
print(result.success)  # True if all expectations pass
```

## Validation Results

The result object contains per-expectation outcomes:

```python
result = validation_def.run()

# Overall
print(result.success)                    # True/False
print(result.statistics)                 # Summary stats

# Per-expectation
for exp_result in result.results:
    print(exp_result.expectation_config)  # What was checked
    print(exp_result.success)             # Pass/fail
    print(exp_result.result)              # Observed values
```

## Result Format

Control detail level when running validations:

| Format | Description |
|--------|-------------|
| `BOOLEAN_ONLY` | Just pass/fail |
| `BASIC` | Pass/fail + observed value |
| `SUMMARY` | Default; partial values + metrics |
| `COMPLETE` | All values and full metrics |

## See Also

- [expectations.md](expectations.md) - Individual Expectation types
- [checkpoints.md](checkpoints.md) - Running suites in production with actions
- [data-context.md](data-context.md) - Where suites are stored
