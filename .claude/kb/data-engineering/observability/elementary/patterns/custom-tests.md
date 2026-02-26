# Custom Tests Pattern

> **Purpose**: Writing custom Elementary tests, extending built-in monitors, and advanced column-level detection
> **MCP Validated**: 2026-02-19

## When to Use

- Built-in monitors do not cover a specific data quality requirement
- Need to combine multiple column anomaly types on specific columns
- Want to validate data against natural language expectations (AI tests)
- Enforcing schema baselines across environments
- Building targeted monitors for high-value business metrics

## Implementation

### Targeted Column Anomalies

```yaml
# models/marts/schema.yml
models:
  - name: fct_revenue
    config:
      elementary:
        timestamp_column: "reported_date"
    columns:
      - name: total_revenue
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - average
                - sum
                - max
                - zero_percent
                - null_percent
              anomaly_sensitivity: 2.5
              time_bucket:
                period: day
                count: 1
              days_back: 30
              anomaly_direction: drop  # Revenue drops are critical

      - name: transaction_count
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - average
                - min
              anomaly_sensitivity: 3
              where_expression: "status = 'completed'"

      - name: customer_id
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - count_distinct
                - null_count
              anomaly_sensitivity: 3
```

### Multi-Dimension Monitoring

```yaml
models:
  - name: fct_events
    config:
      elementary:
        timestamp_column: "event_timestamp"
    tests:
      # Monitor distribution across multiple dimensions simultaneously
      - elementary.dimension_anomalies:
          dimensions:
            - country
            - platform
          anomaly_sensitivity: 2.5
          where_expression: "event_type = 'purchase'"
          time_bucket:
            period: day
            count: 1

      # Separate monitor for a different event type
      - elementary.dimension_anomalies:
          dimensions:
            - country
          where_expression: "event_type = 'signup'"
          anomaly_sensitivity: 3
```

### Schema Baseline Enforcement

```yaml
# Enforce exact schema across environments
models:
  - name: dim_products
    tests:
      - elementary.schema_changes_from_baseline
    columns:
      - name: product_id
        data_type: integer
      - name: product_name
        data_type: varchar
      - name: category
        data_type: varchar
      - name: price
        data_type: numeric
      - name: is_active
        data_type: boolean
      - name: created_at
        data_type: timestamp_ntz
      - name: updated_at
        data_type: timestamp_ntz
```

### JSON Schema Validation

```yaml
# Validate JSON column structure
models:
  - name: raw_api_responses
    columns:
      - name: payload
        tests:
          - elementary.json_schema:
              json_schema: |
                {
                  "type": "object",
                  "required": ["id", "status", "data"],
                  "properties": {
                    "id": {"type": "string"},
                    "status": {"type": "string", "enum": ["success", "error"]},
                    "data": {"type": "object"}
                  }
                }
```

### Exposure Validation

```yaml
# Validate that models referenced by exposures haven't broken
exposures:
  - name: revenue_dashboard
    type: dashboard
    owner:
      name: Analytics Team
      email: analytics@company.com
    depends_on:
      - ref('fct_revenue')
      - ref('dim_customers')

# In schema.yml
models:
  - name: fct_revenue
    tests:
      - elementary.exposure_validation:
          exposure_name: revenue_dashboard
```

### Combining Elementary with Standard dbt Tests

```yaml
models:
  - name: fct_orders
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      # Elementary anomaly tests
      - elementary.volume_anomalies
      - elementary.freshness_anomalies:
          timestamp_column: "updated_at"
      - elementary.schema_changes
    columns:
      - name: order_id
        tests:
          # Standard dbt tests (also captured by Elementary)
          - not_null
          - unique
          # Elementary column monitoring
          - elementary.column_anomalies:
              column_anomalies:
                - null_count
      - name: amount
        tests:
          - not_null
          - elementary.column_anomalies:
              column_anomalies:
                - average
                - zero_percent
              anomaly_direction: drop
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `column_anomalies` | Required | List of metrics to monitor per column |
| `anomaly_sensitivity` | `3` | Z-score threshold |
| `anomaly_direction` | `both` | `spike`, `drop`, or `both` |
| `days_back` | `14` | Training window |
| `where_expression` | None | SQL filter for test scope |
| `dimensions` | Required (dim) | Columns for dimension monitoring |
| `json_schema` | Required (json) | JSON schema definition |
| `exposure_name` | Required (exp) | Name of exposure to validate |

## Available Column Anomaly Metrics

| Category | Metrics |
|----------|---------|
| **Nulls** | `null_count`, `null_percent`, `not_null_percent` |
| **Zeros** | `zero_count`, `zero_percent`, `not_zero_percent` |
| **Numeric** | `average`, `min`, `max`, `sum`, `standard_deviation`, `variance` |
| **Cardinality** | `count_distinct`, `count_distinct_percent` |
| **Missing** | `missing_count`, `missing_percent` |
| **Length** | `average_length`, `max_length`, `min_length` |

## Tagging Strategy

```yaml
# Use tags to organize and filter tests
tests:
  - elementary.volume_anomalies:
      tags: ["elementary", "critical", "tier-1"]
  - elementary.column_anomalies:
      column_anomalies: [average]
      tags: ["elementary", "tier-2"]
```

```bash
# Run only critical Elementary tests
dbt test --select tag:critical

# Generate report for tier-1 tests only
edr report --select tag:tier-1
```

## See Also

- [anomaly-detection](../concepts/anomaly-detection.md)
- [anomaly-monitoring](../patterns/anomaly-monitoring.md)
- [data-monitors](../concepts/data-monitors.md)
