# Testing Strategy Pattern

> **Purpose**: Comprehensive data quality validation across the transformation pipeline
> **MCP Validated**: 2026-02-19

## When to Use

- Establishing data quality standards
- Building trust in data products
- Catching issues before they reach dashboards
- Documenting data expectations

## Implementation

### Layered Testing Approach

```yaml
# models/staging/_stg_models.yml
version: 2

models:
  - name: stg_orders
    description: "Cleaned orders from source"
    columns:
      - name: order_id
        description: "Primary key"
        data_tests:
          - unique
          - not_null
      - name: customer_id
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: order_date
        data_tests:
          - not_null
          - dbt_utils.not_constant
      - name: status
        data_tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
      - name: amount
        data_tests:
          - dbt_utils.expression_is_true:
              expression: ">= 0"
```

### Singular Tests for Business Logic

```sql
-- tests/assert_order_totals_match.sql
-- Orders total should match sum of line items

with order_totals as (
    select order_id, total_amount
    from {{ ref('fct_orders') }}
),

line_item_totals as (
    select order_id, sum(line_amount) as calculated_total
    from {{ ref('fct_order_items') }}
    group by 1
)

select
    o.order_id,
    o.total_amount,
    l.calculated_total
from order_totals o
join line_item_totals l on o.order_id = l.order_id
where abs(o.total_amount - l.calculated_total) > 0.01
```

### Unit Tests for Model Logic

```yaml
# models/marts/_unit_tests.yml
unit_tests:
  - name: test_discount_calculation
    description: "Verify discount logic applies correctly"
    model: fct_orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, subtotal: 100.00, discount_code: 'SAVE10'}
          - {order_id: 2, subtotal: 50.00, discount_code: null}
      - input: ref('dim_discounts')
        rows:
          - {code: 'SAVE10', percent: 10}
    expect:
      rows:
        - {order_id: 1, final_amount: 90.00}
        - {order_id: 2, final_amount: 50.00}
```

## Test Severity Configuration

```yaml
data_tests:
  - unique:
      config:
        severity: error  # Fail the run
  - dbt_utils.recency:
      datepart: day
      field: created_at
      interval: 1
      config:
        severity: warn  # Warning only
        warn_if: ">0"
        error_if: ">7"
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `severity` | error | warn or error |
| `store_failures` | false | Save failing rows to table |
| `limit` | None | Max failing rows to return |

## Testing by Layer

| Layer | Test Focus | Examples |
|-------|------------|----------|
| Sources | Freshness, existence | Source freshness checks |
| Staging | Schema, uniqueness | Primary keys, not_null |
| Intermediate | Relationships | Foreign keys, referential integrity |
| Marts | Business rules | Calculated fields, aggregations |

## Example Usage

```bash
# Run all tests
dbt test

# Run tests for specific model
dbt test --select stg_orders

# Run only unit tests
dbt test --select test_type:unit

# Store failures for debugging
dbt test --store-failures
```

## See Also

- [testing](../concepts/testing.md)
- [sources-seeds](../concepts/sources-seeds.md)
