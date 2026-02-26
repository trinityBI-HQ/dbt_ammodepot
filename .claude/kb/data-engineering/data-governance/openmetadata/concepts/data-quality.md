# Data Quality

> **Purpose**: Test suites, profiler, custom tests, and the data quality framework in OpenMetadata
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

OpenMetadata provides a native data quality framework with built-in test definitions, a data profiler, and test suites. Users can define tests through the UI (no-code), YAML configuration, or the Python SDK. The platform also integrates with external tools like Great Expectations and dbt tests.

## Test Suite Types

| Type | Scope | Execution |
|------|-------|-----------|
| **Executable** | Single table | Runs via associated pipeline on schedule |
| **Logical** | Multiple tables | Groups tests for consolidated views (no pipeline) |

## Built-in Test Categories

### Table-Level Tests

| Test | What It Checks |
|------|---------------|
| `tableRowCountToEqual` | Row count matches expected value |
| `tableRowCountToBeBetween` | Row count within min/max range |
| `tableColumnCountToEqual` | Number of columns matches expected |
| `tableCustomSQLQuery` | Custom SQL returns expected result |
| `tableDiff` | Compare data between two tables |

### Column-Level Tests

| Test | What It Checks |
|------|---------------|
| `columnValuesToBeNotNull` | No null values in column |
| `columnValuesToBeUnique` | All values are unique |
| `columnValuesToBeBetween` | Values within numeric range |
| `columnValueLengthsToBeBetween` | String lengths within range |
| `columnValuesToMatchRegex` | Values match regex pattern |
| `columnValuesToBeInSet` | Values in allowed set |

## Data Quality YAML Configuration

```yaml
source:
  type: TestSuite
  serviceName: snowflake_prod
  sourceConfig:
    config:
      type: TestSuite
      entityFullyQualifiedName: snowflake_prod.analytics.public.orders
processor:
  type: "orm-test-runner"
  config:
    testCases:
      - name: orders_row_count_check
        testDefinitionName: tableRowCountToBeBetween
        parameterValues:
          - name: minValue
            value: 1000
          - name: maxValue
            value: 1000000
      - name: order_id_not_null
        testDefinitionName: columnValuesToBeNotNull
        columnName: order_id
      - name: status_in_valid_set
        testDefinitionName: columnValuesToBeInSet
        columnName: status
        parameterValues:
          - name: allowedValues
            value: "['pending','shipped','delivered','cancelled']"
```

## Data Profiler

The profiler collects statistics on tables and columns:

| Metric | Level | Description |
|--------|-------|-------------|
| Row count | Table | Total number of rows |
| Column count | Table | Number of columns |
| Null count/% | Column | Missing value statistics |
| Unique count/% | Column | Distinct value count |
| Min/Max/Mean | Column | Numeric distribution |
| Histogram | Column | Value distribution chart |
| Sample data | Table | Preview of actual data rows |

## Custom Tests (Python SDK)

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata
from metadata.generated.schema.tests.testCase import TestCase
from metadata.generated.schema.tests.testDefinition import (
    TestDefinition, TestPlatform, EntityType
)

client = OpenMetadata(config)

# Create a custom test definition
custom_test = client.create_or_update(
    CreateTestDefinitionRequest(
        name="customFreshnessCheck",
        entityType=EntityType.TABLE,
        testPlatforms=[TestPlatform.OpenMetadata],
        parameterDefinition=[
            {"name": "maxAgeHours", "dataType": "INT", "required": True}
        ]
    )
)
```

## Observability & Alerts

- **Alerts**: Configure notifications on test failures via Slack, Teams, email
- **Incidents**: Failed tests create incidents for tracking and resolution
- **Dashboards**: View test results over time, track trends, identify patterns
- **SLA monitoring**: Track data freshness against defined expectations

## Integration with External Tools

| Tool | Integration Method |
|------|-------------------|
| Great Expectations | Ingest results via API or connector |
| dbt Tests | Parse test results from run_results.json |
| Soda | API-based result ingestion |

## Related

- [Architecture](../concepts/architecture.md)
- [Governance & Classification](../concepts/governance-classification.md)
- [Ingestion Patterns](../patterns/ingestion-patterns.md)
