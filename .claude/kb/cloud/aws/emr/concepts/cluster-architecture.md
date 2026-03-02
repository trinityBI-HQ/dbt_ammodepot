# Cluster Architecture

> **Purpose**: Master/core/task node topology, instance groups vs fleets, YARN resource management
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

EMR on EC2 clusters consist of three node types: primary (master), core, and task. The primary node runs YARN ResourceManager and HDFS NameNode. Core nodes run YARN NodeManagers and HDFS DataNodes. Task nodes run only YARN containers (executors) with no HDFS storage, making them ideal for Spot instances.

## Node Types

| Node | Services | HDFS? | Min | Spot? | Scaling |
|------|----------|-------|-----|-------|---------|
| Primary (Master) | YARN RM, HDFS NN, Hive Metastore | Yes (NN) | 1 (3 for HA) | No | Fixed |
| Core | YARN NM, HDFS DN | Yes (DN) | 1 | With caution | Yes |
| Task | YARN NM (executors only) | No | 0 | Recommended | Yes |

**High Availability**: EMR supports 3 primary nodes for HA (active/standby YARN RM and HDFS NN). Requires EMR 5.23+.

## Instance Groups vs Instance Fleets

### Instance Groups

```
Primary Instance Group:  1x m5.xlarge (On-Demand)
Core Instance Group:     4x m5.2xlarge (On-Demand)
Task Instance Group:     8x m5.2xlarge (Spot)
```

- One instance type per group
- Simple, predictable capacity
- Auto-scaling via CloudWatch alarms or managed scaling

### Instance Fleets

```
Primary Fleet: target=1, types=[m5.xl, m5a.xl, m6i.xl]
Core Fleet:    target=64 units, types=[m5.2xl(8u), r5.2xl(8u), m6i.2xl(8u)]
Task Fleet:    target=128 units, types=[m5.2xl, m5a.2xl, r5.xl, ...]
```

- Up to 30 instance types per fleet (API/CLI), 5 per fleet (console)
- Allocation strategies: `capacity-optimized`, `lowest-price`, `diversified`
- Weighted capacity via instance units
- Better Spot availability through diversification

## YARN Resource Management

```
Cluster Total: 16 nodes x 8 vCPUs x 32 GB = 128 vCPUs, 512 GB

YARN allocates containers:
  spark.executor.cores = 4
  spark.executor.memory = 28g
  spark.executor.instances = 30  (or dynamic allocation)
```

Key YARN settings configured via EMR Classifications:

| Classification | Key Setting | Purpose |
|----------------|------------|---------|
| `yarn-site` | `yarn.nodemanager.resource.memory-mb` | Max memory per node |
| `yarn-site` | `yarn.nodemanager.resource.cpu-vcores` | Max vCPUs per node |
| `capacity-scheduler` | `yarn.scheduler.capacity.resource-calculator` | DominantResourceCalculator |

## Managed Scaling

Managed scaling automatically adjusts cluster size based on workload:

```json
{
  "ComputeLimits": {
    "UnitType": "InstanceFleetUnits",
    "MinimumCapacityUnits": 4,
    "MaximumCapacityUnits": 100,
    "MaximumOnDemandCapacityUnits": 20,
    "MaximumCoreCapacityUnits": 20
  }
}
```

- Evaluates YARN metrics every 5-10 seconds
- Scales out in ~1 minute, scales in after cooldown
- Supports both instance groups and fleets
- Available EMR 5.30+ (except 6.0.0)

## EMR Releases

| Release Series | Status | Spark | Notes |
|----------------|--------|-------|-------|
| EMR 7.x | Current | 3.5.x | Amazon Linux 2023, latest frameworks |
| EMR 6.x | Maintained | 3.1-3.4 | Amazon Linux 2 |
| EMR 5.x | Legacy | 2.x | Amazon Linux 1, avoid for new clusters |

Always use **EMR 7.12+** for new clusters (Spark 3.5.6, Iceberg 1.10.0).

## Common Mistakes

### Wrong

```bash
# Single instance type in fleet -- defeats purpose
aws emr create-cluster --instance-fleets \
  InstanceFleetType=TASK,TargetSpotCapacity=10,\
  InstanceTypeConfigs=[{InstanceType=m5.xlarge}]
```

### Correct

```bash
# Diversified fleet -- better Spot availability
aws emr create-cluster --instance-fleets \
  InstanceFleetType=TASK,TargetSpotCapacity=10,\
  InstanceTypeConfigs=[{InstanceType=m5.xl},{InstanceType=m5a.xl},\
  {InstanceType=m6i.xl},{InstanceType=r5.xl},{InstanceType=c5.xl}],\
  LaunchSpecifications={SpotSpecification={AllocationStrategy=capacity-optimized,...}}
```

## Related

- [Storage Options](storage-options.md)
- [Cost Optimization](../patterns/cost-optimization.md)
- [Cluster Provisioning](../patterns/cluster-provisioning.md)
