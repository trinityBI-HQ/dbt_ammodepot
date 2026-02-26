# Cost Management

> **Purpose**: Control and reduce Athena spending through format, partitioning, and governance
> **MCP Validated**: 2026-02-19

## When to Use

- Athena costs are growing unexpectedly
- Need to set team-level budgets
- Migrating from always-on warehouse to pay-per-query model

## Cost Model

```
Cost = Data Scanned (TB) × $5.00
Minimum charge: 10 MB per query
Cancelled queries: billed for data already scanned
DDL queries (CREATE, ALTER, DROP): free
Failed queries: not billed
```

## Implementation

### 1. Format Conversion (Biggest Impact)

```sql
-- Calculate current cost baseline
SELECT workgroup,
    SUM(data_scanned_in_bytes) / POWER(1024, 4) AS tb_scanned,
    SUM(data_scanned_in_bytes) / POWER(1024, 4) * 5.0 AS cost_usd
FROM information_schema.query_history
WHERE execution_date >= DATE_ADD('day', -30, NOW())
GROUP BY workgroup;

-- Convert expensive tables to Parquet
CREATE TABLE optimized.events
WITH (format='PARQUET', parquet_compression='SNAPPY',
      partitioned_by=ARRAY['dt'])
AS SELECT * FROM raw.events;
```

### 2. Workgroup Scan Limits

```python
import boto3

athena = boto3.client("athena")

# Per-query limit: reject queries scanning > 10 GB
athena.update_work_group(
    WorkGroup="analytics-team",
    ConfigurationUpdates={
        "BytesScannedCutoffPerQuery": 10 * 1024**3,
        "EnforceWorkGroupConfiguration": True,
    },
)
```

### 3. CloudWatch Cost Monitoring

```python
cloudwatch = boto3.client("cloudwatch")

# Alert when monthly scans exceed 500 GB per workgroup
cloudwatch.put_metric_alarm(
    AlarmName="athena-cost-analytics",
    Namespace="AWS/Athena",
    MetricName="ProcessedBytes",
    Dimensions=[{"Name": "WorkGroup", "Value": "analytics-team"}],
    Statistic="Sum",
    Period=86400,
    EvaluationPeriods=30,
    Threshold=500 * 1024**3,
    ComparisonOperator="GreaterThanThreshold",
    AlarmActions=["arn:aws:sns:us-east-1:123:cost-alerts"],
)
```

### 4. Query Result Reuse

```sql
-- Athena caches results for identical queries (same workgroup)
-- Cache TTL: configurable per workgroup (default: disabled)
```

```python
athena.update_work_group(
    WorkGroup="bi-dashboards",
    ConfigurationUpdates={
        "ResultReuseConfiguration": {
            "ResultReuseByAgeConfiguration": {
                "Enabled": True,
                "MaxAgeInMinutes": 60,  # Reuse results for 1 hour
            }
        }
    },
)
```

**Impact:** Dashboard queries hitting the same data reuse cached results at zero scan cost.

### 5. Provisioned Capacity (Predictable Cost)

| Model | Pricing | Best For |
|-------|---------|----------|
| On-demand | $5/TB scanned | Ad-hoc, variable workloads |
| Provisioned | $0.227/DPU-hour | High-concurrency BI dashboards |

Break-even: ~45 GB/DPU-hour. If scanning more, provisioned is cheaper.

**Feb 2026 updates:**
- **1-minute reservations**: Minimum commitment reduced from 1 hour to 1 minute
- **4 DPU minimum**: Reduced from 24 DPUs, enabling cost-effective short bursts
- **DPU usage tracking**: Monitor DPU consumption per query on Capacity Reservations via CloudWatch or `GetResourceDashboard` API

## Cost Reduction Checklist

| Action | Savings | Effort |
|--------|---------|--------|
| Convert CSV/JSON to Parquet | 60-95% | Medium (one-time CTAS) |
| Add partition pruning | 50-99% | Low (ALTER TABLE) |
| Use column projection | 30-80% | Low (change SELECT) |
| Enable compression | 50-75% | Low (table property) |
| Set workgroup scan limits | Prevent overruns | Low (config) |
| Enable result reuse | 30-80% (repeated queries) | Low (config) |
| Use materialized views | 50-95% (repeated aggs) | Medium (Glue setup) |
| Use 1-min capacity reservations | Avoid over-provisioning | Low (config) |
| Right-size file counts | 10-30% speedup | Medium (repartition) |

## Tagging for Cost Attribution

```python
athena.create_work_group(
    Name="finance-team",
    Tags=[
        {"Key": "Team", "Value": "finance"},
        {"Key": "CostCenter", "Value": "CC-5678"},
        {"Key": "Environment", "Value": "production"},
    ],
)
```

Use AWS Cost Explorer to filter by tags for per-team cost visibility.

## Governance Patterns

| Control | Implementation |
|---------|---------------|
| Per-query limit | `BytesScannedCutoffPerQuery` in workgroup |
| Monthly budget | CloudWatch alarm on `ProcessedBytes` |
| Query review | Require EXPLAIN before large queries |
| Format enforcement | Lake Formation + Glue crawlers |
| Access control | Workgroup IAM policies |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `BytesScannedCutoffPerQuery` | None | Max bytes per query |
| `ResultReuseByAgeConfiguration` | Disabled | Cache query results |
| `PublishCloudWatchMetricsEnabled` | False | Enable cost metrics |
| Provisioned DPU count | N/A | Reserved compute capacity |

## See Also

- [Workgroups](../concepts/workgroups.md)
- [Query Optimization](../patterns/query-optimization.md)
