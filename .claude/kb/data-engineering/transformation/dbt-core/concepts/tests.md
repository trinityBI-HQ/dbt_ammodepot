# Tests

> **Purpose**: Assertions to validate data quality in dbt models and sources
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

dbt tests are assertions about your data. They run as SQL queries that return rows
failing the test condition. If zero rows return, the test passes. dbt provides four
built-in generic tests (unique, not_null, accepted_values, relationships), custom
singular tests, custom generic tests, and unit tests (v1.8+) for testing model
logic with static mock inputs.

## The Pattern

```yaml
# models/staging/schema.yml
version: 2

models:
  - name: stg_orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: customer_id
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: status
        data_tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
```

## Quick Reference

| Test Type | Location | Use Case |
|-----------|----------|----------|
| Generic (built-in) | schema.yml | unique, not_null, etc. |
| Generic (custom) | macros/ or tests/generic/ | Reusable custom logic |
| Singular | tests/ | One-off specific checks |
| Unit (1.8+) | schema.yml | Test model logic with mocks |

## Built-in Generic Tests

```yaml
columns:
  - name: id
    data_tests:
      - unique              # No duplicate values
      - not_null            # No NULL values
  - name: status
    data_tests:
      - accepted_values:    # Value must be in list
          values: ['a', 'b', 'c']
  - name: user_id
    data_tests:
      - relationships:      # FK must exist in parent
          to: ref('users')
          field: id
```

## Singular Tests

```sql
-- tests/assert_positive_order_amounts.sql
select order_id, amount
from {{ ref('fct_orders') }}
where amount < 0
```

## Custom Generic Test

```sql
-- macros/test_is_positive.sql
{% test is_positive(model, column_name) %}
select {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} < 0
{% endtest %}
```

## Common Mistakes

### Wrong

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id  # No tests! Could have duplicates
```

### Correct

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        data_tests: [unique, not_null]
```

## Unit Tests (v1.8+)

```yaml
# models/marts/schema.yml
unit_tests:
  - name: test_order_total_calculation
    model: fct_orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, subtotal: 100.00, tax_rate: 0.08}
          - {order_id: 2, subtotal: 50.00, tax_rate: 0.10}
    expect:
      rows:
        - {order_id: 1, total_amount: 108.00}
        - {order_id: 2, total_amount: 55.00}
```

Unit tests validate model logic with static inputs, enabling TDD-style development.
They run during `dbt test` or `dbt build` and do not query the warehouse.

## Running Tests

```bash
dbt test                              # Run all tests
dbt test --select fct_orders          # Test specific model
dbt test --select +fct_orders         # Test with upstream
dbt test --select test_type:unit      # Unit tests only
dbt test --select test_type:data      # Data tests only
dbt test --store-failures             # Store failures for debugging
```

## Related

- [testing-strategy.md](../patterns/testing-strategy.md)
- [sources.md](sources.md)
- [models.md](models.md)
