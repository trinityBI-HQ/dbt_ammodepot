# Data Quality

> **Purpose**: Rule-based data validation with DQDL
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

AWS Glue Data Quality uses the Data Quality Definition Language (DQDL) to define validation rules. Built on the open-source DeeQu framework, it provides automated recommendations, quality scoring, and CloudWatch integration. Rules can run within ETL jobs or directly against Data Catalog tables.

## DQDL Rule Types

| Rule | Description | Example |
|------|-------------|---------|
| **Completeness** | Non-null ratio | `Completeness "email" >= 0.95` |
| **Uniqueness** | Distinct ratio | `Uniqueness "order_id" = 1.0` |
| **ColumnValues** | Value constraints | `ColumnValues "age" between 0 and 150` |
| **RowCount** | Row count bounds | `RowCount >= 1000` |
| **IsComplete** | No nulls | `IsComplete "customer_id"` |
| **IsUnique** | All unique | `IsUnique "transaction_id"` |
| **ColumnLength** | String length | `ColumnLength "zip_code" = 5` |
| **DataType** | Type check | `DataType "price" = "DOUBLE"` |
| **CustomSql** | SQL expression | `CustomSql "SELECT COUNT(*) FROM primary WHERE..." = 0` |
| **ReferentialIntegrity** | FK checks | `ReferentialIntegrity "order.cust_id" "customer.id" >= 0.99` |
| **DataFreshness** | Timeliness | `DataFreshness "updated_at" <= 24 hours` |

## The Pattern

```python
# DQDL ruleset definition
ruleset = """
Rules = [
    IsComplete "order_id",
    IsUnique "order_id",
    Completeness "customer_email" >= 0.95,
    ColumnValues "order_total" > 0,
    ColumnValues "status" in ["pending", "shipped", "delivered", "cancelled"],
    RowCount between 1000 and 10000000,
    DataFreshness "created_at" <= 24 hours
]
"""
```

## Using in ETL Jobs

```python
from awsglue.transforms import EvaluateDataQuality

# Evaluate quality within ETL pipeline
dq_results = EvaluateDataQuality.apply(
    frame=dyf,
    ruleset=ruleset,
    publishing_options={
        "dataQualityEvaluationContext": "orders_quality",
        "enableDataQualityCloudWatchMetrics": True,
        "enableDataQualityResultsPublishing": True,
    },
)

# Route rows based on quality
good_records = dq_results.filter(lambda r: r["DataQualityEvaluationResult"] == "Passed")
bad_records = dq_results.filter(lambda r: r["DataQualityEvaluationResult"] == "Failed")
```

## DQDL Labels (2025+)

Labels attach business metadata to rules for organization and reporting:

```
Rules = [
    IsComplete "order_id" with labels { "team": "data-platform", "severity": "critical" },
    Completeness "email" >= 0.9 with labels { "team": "marketing", "severity": "warning" },
    RowCount >= 100 with labels { "check_type": "volume", "frequency": "daily" }
]
```

**Benefits:**
- Filter quality results by team, severity, or domain
- Build dashboards grouped by business dimension
- Route alerts based on label metadata

## DQDL Operators

| Operator | Example |
|----------|---------|
| `NOT` | `NOT IsComplete "optional_field"` |
| `NULL` | `ColumnValues "status" != NULL` |
| `EMPTY` | `ColumnValues "name" != EMPTY` |
| `WHITESPACES_ONLY` | `ColumnValues "name" != WHITESPACES_ONLY` |
| `between` | `ColumnValues "age" between 18 and 120` |
| `in` | `ColumnValues "country" in ["US", "CA", "MX"]` |
| `matches` | `ColumnValues "email" matches "[a-z]+@[a-z]+\\.[a-z]+"` |

## Auto-Recommendations

Glue can generate DQDL rules automatically by profiling data:

```bash
aws glue start-data-quality-rule-recommendation-run \
  --data-source '{"GlueTable":{"DatabaseName":"db","TableName":"orders"}}' \
  --role arn:aws:iam::role/GlueRole
```

Returns suggested rules based on statistical analysis of the data.

## Quality Scoring

Each ruleset evaluation produces a composite quality score (0.0-1.0):

| Score | Interpretation |
|-------|---------------|
| 1.0 | All rules passed |
| 0.8-0.99 | Minor issues, investigate |
| 0.5-0.79 | Significant quality problems |
| < 0.5 | Critical -- halt downstream processing |

## Common Mistakes

### Wrong

```python
# No quality checks -- bad data flows to consumers
dyf = read_source()
write_target(dyf)
```

### Correct

```python
# Gate writes behind quality checks
dyf = read_source()
dq = evaluate_quality(dyf, ruleset)
if dq.score >= 0.95:
    write_target(dyf)
else:
    write_quarantine(dyf)
    alert_team(dq.failures)
```

## Related

- [ETL Patterns](../patterns/etl-patterns.md)
- [Data Catalog](../concepts/data-catalog.md)
