# Anomaly Detection

> **Purpose**: How Elementary detects anomalies using statistical methods on time-series data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Elementary uses the Z-score (standard score) method to detect anomalies in your data metrics over time. Data is split into time buckets, and each metric value is compared against its historical distribution. Values exceeding the sensitivity threshold (default: 3 standard deviations) are flagged as anomalies. The model adjusts based on update frequency, **seasonality** (improved in recent releases), and trends. Recent improvements include better seasonality handling, `where_expression` support for scoped detection, and finer sensitivity tuning.

## The Pattern

```yaml
# schema.yml - Configure anomaly detection on a model
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
          anomaly_sensitivity: 3
          days_back: 14
          backfill_days: 2
          anomaly_direction: both
```

## How It Works

```
1. COLLECT    Gather metric values per time bucket (e.g., daily row counts)
2. TRAIN      Build distribution from historical data (days_back window)
3. SCORE      Calculate Z-score: (value - mean) / std_deviation
4. DETECT     Flag if |Z-score| >= anomaly_sensitivity threshold
5. REPORT     Store result in elementary_test_results table
```

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `timestamp_column` | Required | Column used to split data into time buckets |
| `anomaly_sensitivity` | `3` | Z-score threshold (lower = more sensitive) |
| `time_bucket.period` | `day` | Granularity: `hour`, `day`, `week`, `month` |
| `time_bucket.count` | `1` | Number of periods per bucket |
| `days_back` | `14` | Training window for baseline calculation |
| `backfill_days` | `2` | Days to re-evaluate for late-arriving data |
| `anomaly_direction` | `both` | Detect `spike`, `drop`, or `both` |
| `where_expression` | None | SQL filter applied before metric calculation |
| `anomaly_exclude_metrics` | None | Metrics to exclude from detection |

## Sensitivity Tuning

| Sensitivity | Z-Score | Behavior |
|-------------|---------|----------|
| `4` | > 4 std dev | Very conservative, few alerts |
| `3` (default) | > 3 std dev | Standard, catches clear anomalies |
| `2` | > 2 std dev | More sensitive, more alerts |
| `1.5` | > 1.5 std dev | Aggressive, may produce noise |

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| Daily row counts | Pass/Fail | Volume anomaly |
| Time between updates | Pass/Fail | Freshness anomaly |
| Column value distribution | Pass/Fail per column | Column anomaly |
| Categorical group counts | Pass/Fail per dimension | Dimension anomaly |

## Common Mistakes

### Wrong

```yaml
# Anti-pattern: Setting sensitivity too low without understanding data
tests:
  - elementary.volume_anomalies:
      anomaly_sensitivity: 1  # Too sensitive, floods with false positives
```

### Correct

```yaml
# Start with default sensitivity, tune based on alert quality
tests:
  - elementary.volume_anomalies:
      anomaly_sensitivity: 3  # Start here
      days_back: 30           # Longer training window for stable baseline
```

## Global Configuration

```yaml
# dbt_project.yml - Set defaults for all Elementary tests
vars:
  anomaly_sensitivity: 3
  days_back: 14
  backfill_days: 2
  time_bucket:
    period: day
    count: 1
```

## Seasonality Handling

Elementary's anomaly detection now accounts for seasonal patterns in data:
- **Weekly cycles**: Different volume on weekdays vs weekends
- **Monthly patterns**: End-of-month spikes in financial data
- Use `days_back: 30` or longer to capture seasonal patterns in the training window
- Combine with `where_expression` to isolate seasonal segments (e.g., weekday-only)

## Related

- [data-monitors](../concepts/data-monitors.md)
- [anomaly-monitoring](../patterns/anomaly-monitoring.md)
- [test-results](../concepts/test-results.md)
