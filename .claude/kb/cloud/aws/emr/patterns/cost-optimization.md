# Cost Optimization

> **Purpose**: Reducing EMR costs with Spot instances, managed scaling, Graviton, and auto-termination
> **MCP Validated**: 2026-03-01

## When to Use

- Reducing EMR compute costs for batch ETL workloads
- Right-sizing clusters for variable workloads
- Choosing between deployment modes based on cost profile

## Cost Levers Overview

| Strategy | Savings | Risk | Effort |
|----------|---------|------|--------|
| Spot instances (task nodes) | 60-90% | Interruption | Low |
| Managed scaling | 20-40% | None | Low |
| Auto-termination | 20-30% | None | Low |
| Graviton (ARM) instances | 20-40% | Compatibility | Low |
| EMR Serverless | Variable | None | Medium |
| Right-sizing instances | 10-30% | Under-provisioning | Medium |

## Spot Instances

Use Spot for task nodes (no HDFS, interruption-tolerant):

```hcl
# Terraform: Spot task fleet
resource "aws_emr_instance_fleet" "task_spot" {
  cluster_id = aws_emr_cluster.main.id
  name       = "task-spot"

  instance_type_configs {
    instance_type     = "m5.2xlarge"
    weighted_capacity = 8
    bid_price_as_percentage_of_on_demand_price = 100
  }
  instance_type_configs {
    instance_type     = "m5a.2xlarge"
    weighted_capacity = 8
    bid_price_as_percentage_of_on_demand_price = 100
  }
  instance_type_configs {
    instance_type     = "m6i.2xlarge"
    weighted_capacity = 8
    bid_price_as_percentage_of_on_demand_price = 100
  }
  instance_type_configs {
    instance_type     = "r5.xlarge"
    weighted_capacity = 4
    bid_price_as_percentage_of_on_demand_price = 100
  }
  instance_type_configs {
    instance_type     = "c5.2xlarge"
    weighted_capacity = 8
    bid_price_as_percentage_of_on_demand_price = 100
  }

  target_spot_capacity      = 64
  target_on_demand_capacity = 0

  launch_specifications {
    spot_specification {
      allocation_strategy      = "capacity-optimized"
      timeout_action           = "SWITCH_TO_ON_DEMAND"
      timeout_duration_minutes = 10
    }
  }
}
```

### Spot Best Practices

| Do | Don't |
|-----|-------|
| Use Spot for task nodes only | Use Spot for primary (master) nodes |
| Diversify with 5-15 instance types | Use a single instance type |
| Set `capacity-optimized` allocation | Use `lowest-price` for critical jobs |
| Enable `SWITCH_TO_ON_DEMAND` fallback | Let tasks fail on Spot shortage |
| Use Spot for core nodes cautiously | Use Spot core without HDFS replication |

## Managed Scaling

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

- Evaluates YARN pending containers, memory, and app metrics
- Scales out in ~1 minute, scales in with configurable cooldown
- Works with both instance groups and fleets
- **No custom CloudWatch alarms needed** -- replaces legacy auto-scaling

## Auto-Termination

```bash
# Terminate after 1 hour idle
aws emr create-cluster \
  --auto-termination-policy IdleTimeout=3600 \
  ...

# Or for transient clusters: terminate after steps complete
aws emr create-cluster \
  --steps ... \
  --auto-terminate
```

| Mode | Behavior | Use Case |
|------|----------|----------|
| `--auto-terminate` | Terminate after all steps finish | One-off batch jobs |
| `IdleTimeout` | Terminate after N seconds idle | Interactive + batch |
| Termination protection | Prevent accidental termination | Production clusters |

## Graviton (ARM) Instances

Graviton instances offer up to 40% better price-performance:

| Graviton Type | Equivalent x86 | vCPU | Memory | Savings |
|--------------|----------------|------|--------|---------|
| m7g.xlarge | m5.xlarge | 4 | 16 GB | ~20% |
| m7g.2xlarge | m5.2xlarge | 8 | 32 GB | ~20% |
| r7g.2xlarge | r5.2xlarge | 8 | 64 GB | ~20% |
| c7g.2xlarge | c5.2xlarge | 8 | 16 GB | ~20% |

```hcl
# Mix Graviton and x86 in instance fleets
instance_type_configs {
  instance_type     = "m7g.2xlarge"  # Graviton
  weighted_capacity = 8
}
instance_type_configs {
  instance_type     = "m6i.2xlarge"  # x86 fallback
  weighted_capacity = 8
}
```

**Compatibility**: EMR 7.x fully supports Graviton. PySpark and Hive work without changes. Java/Scala JARs compiled for x86 may need recompilation.

## EMR Serverless Cost Model

| Advantage | Detail |
|-----------|--------|
| No idle cost | Scales to zero between jobs |
| Per-second billing | Pay only for vCPU-seconds and GB-seconds |
| No cluster management | Zero operational overhead |
| Auto-managed shuffle | No local storage charges (Dec 2025+) |

**When Serverless is cheaper**: Variable workloads, jobs running < 50% of the time.
**When EC2 is cheaper**: Continuous workloads, reserved/Savings Plan pricing.

## Cost Monitoring

```bash
# Tag clusters for cost allocation
aws emr create-cluster \
  --tags Key=Team,Value=data-eng Key=Project,Value=etl \
  ...

# Check cluster costs via Cost Explorer
# Filter by: Service=EMR, Tag=Team:data-eng
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `MaximumCapacityUnits` | -- | Upper bound for managed scaling |
| `MaximumOnDemandCapacityUnits` | -- | Cap On-Demand (rest filled by Spot) |
| `IdleTimeout` | None | Auto-termination after N seconds |
| `AllocationStrategy` | -- | `capacity-optimized` for Spot |
| `TimeoutAction` | -- | `SWITCH_TO_ON_DEMAND` or `TERMINATE_CLUSTER` |

## See Also

- [Cluster Architecture](../concepts/cluster-architecture.md) -- Instance fleets
- [Cluster Provisioning](cluster-provisioning.md) -- Terraform configuration
- [EMR Serverless](../concepts/emr-serverless.md) -- Serverless cost model
