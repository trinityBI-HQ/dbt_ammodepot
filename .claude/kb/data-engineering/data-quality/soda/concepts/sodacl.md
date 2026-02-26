# SodaCL (Soda Checks Language)

> **Purpose**: YAML-based domain-specific language for defining data quality checks
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

SodaCL (Soda Checks Language) is a YAML-based DSL for expressing data quality rules. You write checks in a `checks.yml` file, and Soda executes them during scans. SodaCL provides 25+ built-in metrics plus custom SQL support.

## File Structure

```yaml
# checks.yml - checks grouped by dataset
checks for orders:
  - row_count > 0
  - missing_count(customer_id) = 0
  - freshness(created_at) < 1d

checks for customers:
  - row_count > 100
  - duplicate_count(email) = 0
```

## Syntax Patterns

### Standard Check: Metric + Threshold

```yaml
checks for dataset_name:
  - metric_name comparison_operator threshold
  - metric_name(column) comparison_operator threshold
```

**Operators:** `>`, `>=`, `<`, `<=`, `=`, `!=`, `between X and Y`

### Threshold Variants

```yaml
checks for orders:
  - row_count > 0                         # fixed
  - row_count between 1000 and 50000      # inclusive
  - avg(price) between (10 and 500)       # exclusive
```

### Configuration Keys

```yaml
checks for orders:
  - invalid_count(email) = 0:
      valid format: email
  - invalid_count(sku) = 0:
      valid regex: "^[A-Z]{2,4}-\\d{5}$"
  - invalid_count(status) = 0:
      valid values: ["pending", "shipped", "delivered"]
  - missing_count(code) = 0:
      missing values: ["N/A", "none", ""]
```

**Note:** Metrics use underscores (`missing_count`), config keys use spaces (`valid format`).

### Warn and Fail Levels

```yaml
checks for orders:
  - missing_count(email):
      warn: when > 5
      fail: when > 50
```

### Named Checks

```yaml
checks for orders:
  - row_count > 0:
      name: "Orders table must not be empty"
```

## Built-in Metrics

**Numeric:** `row_count`, `avg`, `min`, `max`, `sum`, `stddev`, `variance`, `percentile`, `avg_length`, `min_length`, `max_length`

**Missing:** `missing_count`, `missing_percent`

**Validity:** `invalid_count`, `invalid_percent`

**Duplicate:** `duplicate_count`, `duplicate_percent`

**Valid formats:** `email`, `date_us`, `date_eu`, `ip_address`, `uuid`, `credit_card_number`, `phone_number`

## User-Defined Checks

```yaml
checks for products:
  # Expression-based
  - avg_surface < 1068:
      avg_surface expression: AVG(size * distance)
  # Query-based
  - negative_revenue = 0:
      negative_revenue query: |
        SELECT COUNT(*) FROM orders WHERE total < 0
```

## For Each and Filters

```yaml
for each column in orders:
  - missing_percent < 5%

checks for orders:
  - row_count > 0:
      filter: status = 'active'
```

## Common Mistakes

### Wrong

```yaml
# Missing "checks for" block
- row_count > 0
```

### Correct

```yaml
checks for orders:
  - row_count > 0
```

## Related

- [Checks](../concepts/checks.md)
- [Check Patterns](../patterns/check-patterns.md)
