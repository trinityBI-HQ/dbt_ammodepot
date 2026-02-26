# Testing Strategy Pattern

> **Purpose**: Comprehensive data quality testing approach for dbt projects
> **MCP Validated**: 2026-02-19

## When to Use

- Ensuring data quality before production deployment
- Validating primary keys and referential integrity
- Catching data anomalies early in the pipeline
- Building trust in data models with stakeholders

## Implementation

```yaml
# models/marts/schema.yml
version: 2

models:
  - name: fct_orders
    description: Order fact table with one row per order
    columns:
      - name: order_id
        description: Primary key
        data_tests:
          - unique
          - not_null

      - name: customer_id
        description: Foreign key to dim_customers
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
              config:
                severity: warn  # Don't fail build, just warn

      - name: order_date
        data_tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "<= current_date"
              config:
                error_if: ">100"  # Fail if >100 future dates

      - name: amount
        data_tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1000000

      - name: status
        data_tests:
          - accepted_values:
              values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `severity` | error | error or warn |
| `error_if` | ">0" | Threshold to fail test |
| `warn_if` | ">0" | Threshold to warn |
| `store_failures` | False | Save failing rows to warehouse |

## Testing Layers

```yaml
# 1. Source Tests - Validate raw data
sources:
  - name: raw_ecommerce
    tables:
      - name: orders
        columns:
          - name: id
            data_tests:
              - unique
              - not_null

# 2. Staging Tests - Validate transformations
models:
  - name: stg_orders
    data_tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns: [order_id, line_item_id]

# 3. Mart Tests - Validate business logic
models:
  - name: fct_orders
    data_tests:
      - dbt_utils.expression_is_true:
          expression: "total_amount = subtotal + tax_amount"
```

## Custom Generic Test

```sql
-- macros/test_is_positive.sql
{% test is_positive(model, column_name) %}
    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} < 0
{% endtest %}

-- macros/test_row_count_within_range.sql
{% test row_count_within_range(model, min_count, max_count) %}
    with row_count as (
        select count(*) as cnt from {{ model }}
    )
    select cnt
    from row_count
    where cnt < {{ min_count }} or cnt > {{ max_count }}
{% endtest %}
```

```yaml
# Usage
models:
  - name: fct_orders
    data_tests:
      - row_count_within_range:
          min_count: 1000
          max_count: 10000000
    columns:
      - name: amount
        data_tests:
          - is_positive
```

## Singular Test Example

```sql
-- tests/assert_orders_have_customers.sql
-- Returns rows that fail (orphaned orders)
select
    o.order_id,
    o.customer_id
from {{ ref('fct_orders') }} o
left join {{ ref('dim_customers') }} c
    on o.customer_id = c.customer_id
where c.customer_id is null
```

## Unit Tests (dbt 1.8+)

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

## Test Type Selection Guide

| Test Type | Use When | Runs Against |
|-----------|----------|--------------|
| Generic (built-in) | Standard validations (PK, FK, enums) | Warehouse data |
| Generic (custom) | Reusable domain-specific checks | Warehouse data |
| Singular | One-off complex business logic checks | Warehouse data |
| Unit (v1.8+) | Validating transformation logic (TDD) | Static mock inputs |

## Example Usage

```bash
# Run all tests
dbt test

# Run tests for specific model and upstream
dbt test --select +fct_orders

# Store failing rows for debugging
dbt test --store-failures

# Run only unit tests or data tests
dbt test --select test_type:unit
dbt test --select test_type:data

# Run tests in CI/CD
dbt build  # Runs models and tests in DAG order
```

## See Also

- [tests.md](../concepts/tests.md)
- [sources.md](../concepts/sources.md)
- [custom-macros.md](custom-macros.md)
