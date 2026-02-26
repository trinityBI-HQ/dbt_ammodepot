# Anomaly Monitoring Pattern

> **Purpose**: Configuring anomaly detection monitors in schema.yml for comprehensive data quality coverage
> **MCP Validated**: 2026-02-19

## When to Use

- Need to detect unexpected changes in data volume or freshness
- Want column-level quality monitoring without manual threshold setting
- Tracking distribution shifts in categorical data
- Monitoring schema changes across your data warehouse

## Implementation

### Basic Monitoring Setup

```yaml
# models/marts/schema.yml
models:
  - name: fct_orders
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      # Monitor row count trends
      - elementary.volume_anomalies

      # Monitor data freshness
      - elementary.freshness_anomalies:
          timestamp_column: "updated_at"

      # Detect schema changes
      - elementary.schema_changes

      # Monitor all columns automatically
      - elementary.all_columns_anomalies
```

### Volume Monitoring with Filters

```yaml
models:
  - name: fct_events
    config:
      elementary:
        timestamp_column: "event_timestamp"
    tests:
      - elementary.volume_anomalies:
          time_bucket:
            period: hour
            count: 1
          where_expression: "event_type = 'purchase'"
          anomaly_sensitivity: 2.5
          days_back: 30
          anomaly_direction: drop  # Only alert on volume drops
```

### Column-Level Anomaly Detection

```yaml
models:
  - name: fct_transactions
    config:
      elementary:
        timestamp_column: "transaction_date"
    columns:
      - name: amount
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - average
                - max
                - zero_percent
                - null_percent
              anomaly_sensitivity: 3
              time_bucket:
                period: day
                count: 1

      - name: currency_code
        tests:
          - elementary.column_anomalies:
              column_anomalies:
                - count_distinct
              anomaly_sensitivity: 2
```

### Dimension Monitoring

```yaml
models:
  - name: fct_events
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      - elementary.dimension_anomalies:
          dimensions:
            - country
            - platform
            - event_type
          where_expression: "country is not null"
          anomaly_sensitivity: 3
```

### Event Freshness (Streaming/Near-Real-Time)

```yaml
models:
  - name: stg_clickstream
    tests:
      - elementary.event_freshness_anomalies:
          timestamp_column: "loaded_at"
          event_timestamp_column: "clicked_at"
          time_bucket:
            period: hour
            count: 1
```

### Schema Baseline Enforcement

```yaml
models:
  - name: dim_customers
    tests:
      - elementary.schema_changes_from_baseline
    columns:
      - name: customer_id
        data_type: integer
      - name: email
        data_type: varchar
      - name: created_at
        data_type: timestamp_ntz
      - name: is_active
        data_type: boolean
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `timestamp_column` | Required | Column for time bucketing |
| `anomaly_sensitivity` | `3` | Z-score threshold |
| `time_bucket.period` | `day` | `hour`, `day`, `week`, `month` |
| `days_back` | `14` | Training window |
| `backfill_days` | `2` | Re-evaluation window |
| `anomaly_direction` | `both` | `spike`, `drop`, `both` |
| `where_expression` | None | SQL filter |
| `dimensions` | Required (dim) | Columns to group by |
| `column_anomalies` | Required (col) | Metric types to track |

## Recommended Monitoring Strategy

```yaml
# Tier 1: Apply to ALL production models (low config)
tests:
  - elementary.volume_anomalies
  - elementary.freshness_anomalies
  - elementary.schema_changes

# Tier 2: Apply to critical models (medium config)
tests:
  - elementary.all_columns_anomalies
  - elementary.dimension_anomalies

# Tier 3: Apply to high-value columns (targeted config)
columns:
  - name: revenue
    tests:
      - elementary.column_anomalies:
          column_anomalies: [average, sum, null_percent]
```

## Global Defaults

```yaml
# dbt_project.yml - Set project-wide defaults
vars:
  anomaly_sensitivity: 3
  days_back: 14
  backfill_days: 2
  time_bucket:
    period: day
    count: 1
```

## Example Usage

```bash
# Run all Elementary tests
dbt test --select tag:elementary

# Run tests for a specific model
dbt test --select fct_orders

# Generate report after tests
edr report -d 14
```

## See Also

- [anomaly-detection](../concepts/anomaly-detection.md)
- [data-monitors](../concepts/data-monitors.md)
- [custom-tests](../patterns/custom-tests.md)
