# Soda Checks

> **Purpose**: Data quality assertions using metrics and thresholds in SodaCL
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A Soda check is a single data quality assertion defined in a `checks.yml` file. Each check combines a metric (what to measure) with a threshold (acceptable values). Checks are grouped by dataset and executed during a scan.

## Check Categories

### Standard Checks (Metric + Threshold)

```yaml
checks for orders:
  # Numeric metrics
  - row_count > 0
  - avg(price) between 10 and 500
  - max(quantity) <= 1000
  - duplicate_count(order_id) = 0
  # Missing metrics (NULL detection)
  - missing_count(customer_id) = 0
  - missing_percent(email) < 5%
  # Validity metrics (format validation)
  - invalid_count(email) = 0:
      valid format: email
  - invalid_count(status) = 0:
      valid values: ["pending", "shipped", "delivered"]
```

### Freshness Check

```yaml
checks for orders:
  - freshness(created_at) < 1d
  - freshness(updated_at) < 6h
```

### Schema Check

```yaml
checks for orders:
  - schema:
      fail:
        when required column missing: [id, customer_id, created_at]
        when wrong column type:
          id: integer
          revenue: decimal
      warn:
        when forbidden column present: [temp_col, debug_flag]
```

### Reference Check (Cross-Dataset)

```yaml
checks for orders:
  - values in (customer_id) must exist in customers (id)
```

### Cross Check (Row Count Comparison)

```yaml
checks for orders_staging:
  - row_count same as orders_prod
```

### Failed Rows (Row-Level Logic)

```yaml
checks for orders:
  - failed rows:
      name: "End date must be after start date"
      fail condition: end_date <= start_date
```

### User-Defined SQL Metric

```yaml
checks for orders:
  - avg_order_value > 25:
      avg_order_value expression: AVG(total_amount)
  - revenue_check:
      revenue_check query: |
        SELECT COUNT(*) FROM orders
        WHERE total_amount < 0
      fail: when > 0
```

## Warn and Fail Thresholds

```yaml
checks for orders:
  - missing_count(email):
      warn: when > 5
      fail: when > 50
  - row_count:
      warn: when < 1000
      fail: when < 100
```

## Check Naming and For Each

```yaml
checks for orders:
  - row_count > 0:
      name: "Orders table must not be empty"

for each column in orders:
  - missing_count < 5%:
      exclude columns: [optional_notes]
```

## Quick Reference

| Check Type | Use Case | Requires Cloud |
|------------|----------|----------------|
| Standard (numeric/missing/validity) | Basic quality gates | No |
| Freshness | Data recency SLAs | No |
| Schema | Column/type validation | No |
| Reference | Foreign key integrity | No |
| Cross | Dataset parity | No |
| Failed rows | Business rule validation | No |
| Anomaly detection | ML-based drift detection | Yes |
| Distribution | Statistical distribution | Yes |

## Related

- [SodaCL Syntax](../concepts/sodacl.md)
- [Check Patterns](../patterns/check-patterns.md)
- [Monitoring and Alerting](../patterns/monitoring-alerting.md)
