# Data Monitors

> **Purpose**: Types of Elementary monitors for freshness, volume, schema changes, and dimension anomalies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Elementary provides pre-built data monitors that run as dbt tests. Each monitor type tracks a specific aspect of data health: how often data arrives (freshness), how much data arrives (volume), whether the structure changed (schema), and whether distributions shifted (dimensions). Monitors are configured in `schema.yml` and execute during `dbt test`.

**Automated out-of-box monitors (Elementary 2.0):** Freshness, volume, and schema change monitors can now activate automatically with zero manual configuration when using Elementary Cloud/2.0. No `schema.yml` entries required -- monitors detect patterns from connected tables.

## Volume Anomalies

Monitors the row count of a table over time per time bucket. Detects unexpected data spikes, drops, or complete data loss.

```yaml
models:
  - name: orders
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      - elementary.volume_anomalies:
          time_bucket:
            period: day
            count: 1
```

## Freshness Anomalies

Monitors the time between data updates. Detects when data stops arriving or arrives late compared to historical patterns.

```yaml
models:
  - name: orders
    tests:
      - elementary.freshness_anomalies:
          timestamp_column: "updated_at"
          tags: ["elementary"]
          config:
            severity: warn
```

## Event Freshness Anomalies

Monitors the latency of event data -- how long it takes each event to appear in the table after it occurred. Useful for streaming or near-real-time pipelines.

```yaml
models:
  - name: click_events
    tests:
      - elementary.event_freshness_anomalies:
          timestamp_column: "loaded_at"
          event_timestamp_column: "event_timestamp"
```

## Schema Changes

Detects structural changes: deleted tables, added/removed columns, and data type changes. No configuration beyond adding the test.

```yaml
models:
  - name: orders
    tests:
      - elementary.schema_changes
```

## Schema Changes from Baseline

Compares the current schema against a defined baseline of expected columns. Fails when reality diverges from expectation.

```yaml
models:
  - name: orders
    tests:
      - elementary.schema_changes_from_baseline
    columns:
      - name: order_id
        data_type: integer
      - name: customer_id
        data_type: integer
      - name: amount
        data_type: numeric
```

## Dimension Anomalies

Monitors the distribution of categorical data across dimensions. Detects shifts in group proportions (e.g., sudden drop in events from one country).

```yaml
models:
  - name: events
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      - elementary.dimension_anomalies:
          dimensions:
            - country
            - event_type
          where_expression: "country is not null"
```

## All Columns Anomalies

Runs column-level anomaly detection across every column in the table automatically. Elementary infers appropriate metrics per column type.

```yaml
models:
  - name: orders
    config:
      elementary:
        timestamp_column: "created_at"
    tests:
      - elementary.all_columns_anomalies
```

## Monitor Comparison

| Monitor | Detects | Requires Timestamp | Config Complexity |
|---------|---------|-------------------|-------------------|
| `volume_anomalies` | Row count changes | Yes | Low |
| `freshness_anomalies` | Late/missing updates | Yes | Low |
| `event_freshness_anomalies` | Event ingestion delay | Yes (2 columns) | Medium |
| `schema_changes` | DDL changes | No | None |
| `schema_changes_from_baseline` | Schema drift from spec | No | Medium |
| `dimension_anomalies` | Distribution shifts | Yes | Medium |
| `column_anomalies` | Column metric changes | Yes | Medium |
| `all_columns_anomalies` | All column metrics | Yes | Low |

## Out-of-Box Monitors (Elementary 2.0)

Elementary 2.0 introduces automated monitors that require no configuration:

| Monitor | Behavior |
|---------|----------|
| **Freshness** | Auto-detects expected update cadence per table |
| **Volume** | Tracks row count patterns with seasonality |
| **Schema** | Detects structural changes across all tables |

These complement the dbt test-based monitors above. OSS users still configure monitors in `schema.yml`; Elementary 2.0 users get baseline coverage automatically.

## Related

- [anomaly-detection](../concepts/anomaly-detection.md)
- [anomaly-monitoring](../patterns/anomaly-monitoring.md)
- [custom-tests](../patterns/custom-tests.md)
