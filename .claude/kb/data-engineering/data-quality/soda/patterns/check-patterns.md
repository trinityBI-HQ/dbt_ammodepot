# Common Check Patterns

> **Purpose**: Reusable SodaCL check patterns for typical data quality use cases
> **MCP Validated**: 2026-02-19

## When to Use

- Starting a new data quality initiative with Soda
- Establishing baseline checks for datasets
- Building quality gates for data pipelines
- Defining team-wide check templates

## Pattern 1: Bronze Layer (Raw Ingestion)

Minimal checks for raw landing data:

```yaml
checks for raw_orders:
  # Table not empty
  - row_count > 0:
      name: "Raw orders received"

  # Primary key exists
  - missing_count(id) = 0
  - duplicate_count(id) = 0

  # Data is fresh
  - freshness(ingested_at) < 2h:
      name: "Raw data freshness SLA"

  # Schema stability
  - schema:
      fail:
        when required column missing: [id, customer_id, total, created_at]
```

## Pattern 2: Silver Layer (Cleaned/Transformed)

Thorough validation after transformation:

```yaml
checks for clean_orders:
  # Volume checks
  - row_count > 0
  - row_count between 1000 and 100000

  # Completeness (critical columns)
  - missing_count(customer_id) = 0
  - missing_count(order_date) = 0
  - missing_percent(email) < 5%

  # Uniqueness
  - duplicate_count(order_id) = 0

  # Validity
  - invalid_count(email) = 0:
      valid format: email
  - invalid_count(status) = 0:
      valid values: ["pending", "processing", "shipped", "delivered", "cancelled"]

  # Range checks
  - min(total_amount) >= 0
  - max(total_amount) < 1000000

  # Business logic
  - failed rows:
      name: "Ship date after order date"
      fail condition: shipped_at < order_date
```

## Pattern 3: Gold Layer (Business Metrics)

Aggregate validation for reporting tables:

```yaml
checks for daily_revenue:
  - row_count > 0
  - freshness(report_date) < 1d

  # Statistical checks
  - avg(total_revenue) between 10000 and 1000000
  - min(total_revenue) >= 0
  - missing_count(total_revenue) = 0

  # Completeness of dimensions
  - missing_count(region) = 0
  - missing_count(product_category) = 0
```

## Pattern 4: Referential Integrity

Cross-dataset validation:

```yaml
checks for orders:
  - values in (customer_id) must exist in customers (id)
  - values in (product_id) must exist in products (id)

checks for line_items:
  - values in (order_id) must exist in orders (id)
```

## Pattern 5: Data Source Parity

Validate ETL did not lose rows:

```yaml
checks for orders_target:
  - row_count same as orders_source
```

## Pattern 6: Custom SQL Checks

```yaml
checks for orders:
  # Aggregation check
  - daily_total > 0:
      daily_total query: |
        SELECT SUM(total_amount) FROM orders
        WHERE order_date = CURRENT_DATE - INTERVAL '1 day'

  # Orphan detection
  - orphan_count = 0:
      orphan_count query: |
        SELECT COUNT(*) FROM orders o
        LEFT JOIN customers c ON o.customer_id = c.id
        WHERE c.id IS NULL
```

## Pattern 7: Multi-Environment Checks

Organize checks by environment:

```yaml
# checks/base.yml (shared checks)
checks for orders:
  - row_count > 0
  - missing_count(id) = 0

# checks/production.yml (stricter thresholds)
checks for orders:
  - row_count > 10000
  - freshness(created_at) < 1h
  - missing_count(customer_id) = 0
  - missing_count(email) = 0
```

```bash
# Dev: relaxed checks only
soda scan -d dev_db -c config.yml checks/base.yml

# Production: base + strict checks
soda scan -d prod_db -c config.yml checks/base.yml checks/production.yml
```

## Pattern 8: Warn Before Fail (Progressive Alerting)

```yaml
checks for orders:
  - row_count:
      warn: when < 1000
      fail: when < 100
  - missing_count(email):
      warn: when > 10
      fail: when > 100
  - freshness(created_at):
      warn: when > 6h
      fail: when > 24h
```

## Configuration Tips

| Tip | Rationale |
|-----|-----------|
| One checks file per dataset or domain | Easier maintenance and ownership |
| Use warn + fail thresholds | Catch issues before they become critical |
| Name critical checks | Clearer reporting in Soda Cloud |
| Start with schema + freshness + row_count | Covers 80% of basic quality issues |
| Add validity checks incrementally | Profile data first, then codify rules |

## See Also

- [SodaCL Syntax](../concepts/sodacl.md)
- [Checks](../concepts/checks.md)
- [CI/CD Integration](../patterns/ci-cd-integration.md)
