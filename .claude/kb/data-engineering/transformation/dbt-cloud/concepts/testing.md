# Testing

> **Purpose**: Data quality validation with generic, singular, and unit tests
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

dbt provides three test types: generic data tests (YAML-defined assertions), singular data tests (SQL queries returning failing rows), and unit tests (v1.8+, stable) that validate model logic with static mock inputs for TDD-style development. Tests run with `dbt test` or as part of `dbt build`.

## Generic Data Tests

```yaml
# models/staging/_stg_orders.yml
version: 2

models:
  - name: stg_orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: status
        data_tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
      - name: customer_id
        data_tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
```

## Singular Data Tests

```sql
-- tests/assert_positive_amounts.sql
-- Returns rows that fail the test
select
    order_id,
    amount
from {{ ref('stg_orders') }}
where amount < 0
```

## Unit Tests (v1.8+, stable)

Unit tests validate model transformation logic with static mock inputs.
They do not query the warehouse and enable TDD-style development.

```yaml
# models/marts/_unit_tests.yml
unit_tests:
  - name: test_order_total_calculation
    model: fct_orders
    given:
      - input: ref('stg_order_items')
        rows:
          - {order_id: 1, quantity: 2, unit_price: 10.00}
          - {order_id: 1, quantity: 1, unit_price: 5.00}
    expect:
      rows:
        - {order_id: 1, total_amount: 25.00}
```

## Test Commands

| Command | Purpose |
|---------|---------|
| `dbt test` | Run all tests |
| `dbt test --select test_type:data` | Data tests only |
| `dbt test --select test_type:unit` | Unit tests only |
| `dbt test --select stg_orders` | Tests for one model |

## Test Configuration

```yaml
data_tests:
  - unique:
      config:
        severity: warn
        error_if: ">100"
        warn_if: ">10"
```

## Common Mistakes

### Wrong

```yaml
# Old syntax (deprecated)
tests:
  - unique
```

### Correct

```yaml
# New syntax (v1.8+)
data_tests:
  - unique
```

## Related

- [Testing Strategy](../patterns/testing-strategy.md)
- [sources-seeds](sources-seeds.md)
