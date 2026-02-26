# Data Pipeline Cost Optimization

> **Purpose**: Reduce compute costs for Spark, Databricks, and EMR/Dataproc data pipelines
> **MCP Validated**: 2026-02-19

## When to Use

- Spark/Databricks pipeline compute costs are the largest budget item
- Clusters are over-provisioned or running idle between jobs
- Teams use all-purpose clusters for production workloads
- Spot/preemptible instances are not being utilized
- Pipeline run times are acceptable but costs are not

## Databricks Optimization

### Use Jobs Clusters (Not All-Purpose)

All-purpose clusters cost 3-4x more in DBUs than Jobs clusters. This is the single highest-impact optimization for Databricks.

```python
# Dagster: Configure Databricks job with Jobs cluster
from dagster_databricks import databricks_client

databricks_job_config = {
    "name": "bronze-ingest-daily",
    "tasks": [{
        "task_key": "ingest",
        "new_cluster": {
            "spark_version": "14.3.x-scala2.12",
            "node_type_id": "i3.xlarge",
            "num_workers": 4,
            "aws_attributes": {
                "availability": "SPOT_WITH_FALLBACK",
                "spot_bid_price_percent": 100,
                "first_on_demand": 1  # Driver on-demand, workers spot
            },
            "autoscale": {
                "min_workers": 2,
                "max_workers": 8
            },
            "custom_tags": {
                "team": "data-engineering",
                "pipeline": "bronze-ingest",
                "environment": "prod"
            }
        },
        "spark_python_task": {
            "python_file": "dbfs:/jobs/bronze_ingest.py"
        }
    }]
}
```

### Cluster Pool Configuration

Cluster pools reduce start time (30-60s vs 5-10 min) without paying DBU markup for idle nodes.

```json
{
  "instance_pool_name": "data-eng-pool",
  "node_type_id": "i3.xlarge",
  "min_idle_instances": 2,
  "max_capacity": 20,
  "idle_instance_autotermination_minutes": 15,
  "aws_attributes": {
    "availability": "SPOT",
    "spot_bid_price_percent": 100
  }
}
```

### Photon Engine

Enable Photon for SQL-heavy workloads -- reduces DBU consumption per task by accelerating query execution.

```python
# Enable Photon in cluster config
{
    "runtime_engine": "PHOTON",
    "spark_version": "14.3.x-photon-scala2.12"
}
```

## Spark on EMR/Dataproc

### Spot Instance Fleet Strategy

```json
{
  "InstanceFleets": [
    {
      "Name": "driver",
      "InstanceFleetType": "MASTER",
      "TargetOnDemandCapacity": 1,
      "InstanceTypeConfigs": [
        {"InstanceType": "r5.2xlarge", "WeightedCapacity": 1}
      ]
    },
    {
      "Name": "workers",
      "InstanceFleetType": "CORE",
      "TargetOnDemandCapacity": 2,
      "TargetSpotCapacity": 8,
      "LaunchSpecifications": {
        "SpotSpecification": {
          "TimeoutDurationMinutes": 10,
          "AllocationStrategy": "capacity-optimized"
        }
      },
      "InstanceTypeConfigs": [
        {"InstanceType": "r5.2xlarge", "WeightedCapacity": 1},
        {"InstanceType": "r5a.2xlarge", "WeightedCapacity": 1},
        {"InstanceType": "r5d.2xlarge", "WeightedCapacity": 1},
        {"InstanceType": "r6i.2xlarge", "WeightedCapacity": 1}
      ]
    }
  ]
}
```

**Key decisions:**
- Driver: Always on-demand (job fails if driver is terminated)
- Core nodes: Mix of on-demand (min viable) + spot (burst capacity)
- Task nodes: 100% spot (stateless, can be interrupted)
- Diversify instance types: 4+ types for better spot availability

### Dataproc Preemptible Workers

```bash
gcloud dataproc clusters create my-cluster \
  --region=us-central1 \
  --master-machine-type=n2-standard-4 \
  --worker-machine-type=n2-standard-4 \
  --num-workers=2 \
  --num-secondary-workers=6 \
  --secondary-worker-type=preemptible \
  --autoscaling-policy=data-eng-policy
```

## Autoscaling Configuration

| Setting | Recommendation | Rationale |
|---------|---------------|-----------|
| Min workers | 1-2 | Minimal baseline for small tasks |
| Max workers | Based on data volume | Cap to prevent runaway costs |
| Scale-up speed | Fast (default) | Don't waste time under-provisioned |
| Scale-down grace | 5-10 min | Avoid thrashing during stage boundaries |
| Auto-terminate | 15-30 min idle | Prevent forgotten running clusters |

## Scheduling Optimization

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| Off-peak scheduling | 10-30% (spot prices lower) | Schedule jobs during low-demand hours |
| Pipeline consolidation | 20-40% | Batch small jobs into fewer cluster starts |
| Incremental processing | 50-80% | Process only new/changed data |
| Skip unnecessary runs | Variable | Add data-change detection before execution |

## Configuration Quick Reference

| Parameter | Cost Impact | Recommended Value |
|-----------|------------|-------------------|
| `availability` | High | `SPOT_WITH_FALLBACK` |
| `autotermination_minutes` | Medium | 15-30 |
| `autoscale.max_workers` | High | Size for 90th percentile workload |
| `first_on_demand` | Low | 1 (driver only) |
| `runtime_engine` | Medium | `PHOTON` for SQL workloads |
| Cluster type | Very High | Jobs (not All-Purpose) |

## See Also

- [Warehouse Cost Management](warehouse-cost-management.md) -- SQL warehouse optimization
- [Monitoring and Alerting](monitoring-alerting.md) -- Track pipeline cost metrics
- [Cloud Billing](../concepts/cloud-billing.md) -- Understanding compute pricing
