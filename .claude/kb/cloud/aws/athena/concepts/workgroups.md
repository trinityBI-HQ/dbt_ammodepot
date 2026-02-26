# Workgroups

> **Purpose**: Isolate queries, control costs, and manage access by team
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Athena workgroups separate users, queries, and costs. Each workgroup has its own query history, result output location, encryption settings, and data scan limits. Use workgroups to enforce cost controls and isolate team workloads.

## Key Properties

| Property | Description |
|----------|-------------|
| **Name** | Unique identifier (e.g., `analytics-team`, `data-eng`) |
| **Output Location** | S3 path for query results |
| **Encryption** | SSE-S3, SSE-KMS, or CSE-KMS for results |
| **Engine Version** | Athena v2 or v3 (Trino) |
| **Data Scan Limit** | Max bytes per query and per workgroup |
| **Publish Metrics** | CloudWatch metrics for cost tracking |

## The Pattern

```python
import boto3

athena = boto3.client("athena")

athena.create_work_group(
    Name="analytics-team",
    Configuration={
        "ResultConfiguration": {
            "OutputLocation": "s3://athena-results/analytics-team/",
            "EncryptionConfiguration": {"EncryptionOption": "SSE_KMS", "KmsKey": "alias/athena-key"},
        },
        "EnforceWorkGroupConfiguration": True,  # Override client settings
        "PublishCloudWatchMetricsEnabled": True,
        "BytesScannedCutoffPerQuery": 10 * 1024**3,  # 10 GB per query
        "EngineVersion": {"SelectedEngineVersion": "Athena engine version 3"},
    },
    Tags=[
        {"Key": "Team", "Value": "analytics"},
        {"Key": "CostCenter", "Value": "CC-1234"},
    ],
)
```

## Cost Controls

### Per-Query Limit

```python
# Reject queries that would scan more than 10 GB
"BytesScannedCutoffPerQuery": 10 * 1024**3
```

Query fails with `QueryExceedsBytesScannedLimit` if exceeded. Prevents accidental full-table scans.

### Workgroup Budget (CloudWatch)

```python
# Set monthly budget alarm
cloudwatch = boto3.client("cloudwatch")

cloudwatch.put_metric_alarm(
    AlarmName="athena-analytics-monthly-cost",
    MetricName="ProcessedBytes",
    Namespace="AWS/Athena",
    Dimensions=[{"Name": "WorkGroup", "Value": "analytics-team"}],
    Statistic="Sum",
    Period=2592000,  # 30 days
    Threshold=1024**4,  # 1 TB
    ComparisonOperator="GreaterThanThreshold",
    AlarmActions=["arn:aws:sns:us-east-1:123:cost-alerts"],
)
```

## Provisioned Capacity

For predictable, high-concurrency workloads:

```python
athena.create_capacity_reservation(
    Name="bi-dashboards",
    TargetDpus=24,  # 24 DPUs reserved (minimum: 4 DPUs)
)

# Assign to workgroup
athena.update_work_group(
    WorkGroup="bi-team",
    ConfigurationUpdates={
        "CapacityAssignment": {"CapacityReservationName": "bi-dashboards"},
    },
)
```

**When to use provisioned capacity:**
- Concurrent BI dashboard queries (QuickSight)
- SLA-bound reporting jobs
- Predictable query patterns where reserved pricing is cheaper

### Feb 2026 Updates

- **1-minute reservations**: Minimum commitment reduced from 1 hour to 1 minute
- **4 DPU minimum**: Reduced from 24 DPUs, enabling cost-effective short bursts
- **DPU usage tracking**: Per-query DPU consumption via CloudWatch or `GetResourceDashboard` API

## IAM Integration

```json
{
  "Effect": "Allow",
  "Action": ["athena:StartQueryExecution", "athena:GetQueryResults"],
  "Resource": "arn:aws:athena:us-east-1:123:workgroup/analytics-team"
}
```

Users can be restricted to specific workgroups via IAM policies.

## EnforceWorkGroupConfiguration

| Setting | Enforced=True | Enforced=False |
|---------|---------------|----------------|
| Output location | Workgroup's S3 path always used | Client can override |
| Encryption | Workgroup encryption always applied | Client can override |
| Engine version | Workgroup version always used | Client can override |

**Recommendation:** Always set `EnforceWorkGroupConfiguration: True` for governance.

## Workgroup Design Patterns

| Pattern | Workgroups | Rationale |
|---------|-----------|-----------|
| By team | `analytics`, `data-eng`, `finance` | Cost attribution, access control |
| By environment | `dev`, `staging`, `prod` | Isolation, different limits |
| By use case | `ad-hoc`, `bi-dashboards`, `etl` | Different capacity/limits |
| Combined | `prod-analytics`, `dev-data-eng` | Granular control |

## Common Mistakes

**Don't** use the default "primary" workgroup for everyone -- no cost visibility, no limits.
**Do** create dedicated workgroups with enforced configs, scan limits, and cost tags.

## Related

- [Query Engine](../concepts/query-engine.md)
- [Cost Management](../patterns/cost-management.md)
