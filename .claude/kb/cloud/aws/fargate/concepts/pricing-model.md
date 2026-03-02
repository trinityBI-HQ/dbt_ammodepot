# Pricing Model

> **Purpose**: Fargate billing mechanics -- vCPU/memory per-second, Spot, Savings Plans, cost optimization
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

AWS Fargate bills per-second for vCPU and memory from the time your container image starts pulling until the task terminates, with a 1-minute minimum. There are no upfront costs or EC2 instances to manage. Cost optimization strategies include Fargate Spot (up to 70% off), Compute Savings Plans (up to 50% off), and ARM/Graviton processors (20% cheaper than x86).

## The Pattern

```text
Task Cost = (vCPU-seconds x vCPU rate) + (GB-seconds x memory rate) + storage surcharge

Example: 1 vCPU, 2 GB, running 1 hour (US East)
  vCPU:    3600s x $0.000011244 = $0.04048
  Memory:  3600s x 2 x $0.000001235 = $0.008892
  Total:   $0.04937/hour = ~$35.55/month
```

## Quick Reference

| Resource | On-Demand (Linux/x86) | Fargate Spot | ARM/Graviton |
|----------|----------------------|--------------|--------------|
| vCPU per hour | $0.04048 | $0.01215 | $0.03238 |
| Memory (GB) per hour | $0.004445 | $0.001334 | $0.003556 |
| Spot discount | -- | ~70% | -- |
| ARM discount | -- | -- | ~20% |

## Billing Mechanics

| Factor | Detail |
|--------|--------|
| Billing start | When container image pull begins |
| Billing end | When task terminates (all containers stopped) |
| Minimum charge | 1 minute |
| Granularity | Per-second after first minute |
| Ephemeral storage | Free for first 20 GB; $0.000111/GB/hr beyond that |
| Data transfer | Standard AWS data transfer rates apply |

## Monthly Cost Estimates (US East, On-Demand, Linux/x86)

| Configuration | Per Hour | Per Month (730h) |
|---------------|----------|------------------|
| 0.25 vCPU, 0.5 GB | $0.01234 | $9.01 |
| 0.5 vCPU, 1 GB | $0.02469 | $18.02 |
| 1 vCPU, 2 GB | $0.04937 | $36.04 |
| 2 vCPU, 4 GB | $0.09874 | $72.08 |
| 4 vCPU, 8 GB | $0.19749 | $144.17 |
| 4 vCPU, 16 GB | $0.23305 | $170.13 |
| 8 vCPU, 32 GB | $0.53809 | $392.81 |
| 16 vCPU, 64 GB | $1.07619 | $785.62 |

## Fargate Spot

Fargate Spot uses spare AWS capacity at up to 70% discount. Tasks can be interrupted with a 2-minute SIGTERM warning.

**Best for:**
- Batch processing, data pipelines, CI/CD runners
- Queue-based workers that can resume from checkpoints
- Development/staging environments

**Not suitable for:**
- User-facing API services requiring high availability
- Stateful workloads without checkpoint/resume logic

```json
{
  "capacityProviderStrategy": [
    { "capacityProvider": "FARGATE", "weight": 1, "base": 2 },
    { "capacityProvider": "FARGATE_SPOT", "weight": 4 }
  ]
}
```

This runs 2 tasks on-demand (baseline) and scales additional tasks on Spot (80% Spot ratio).

## Compute Savings Plans

| Plan | Discount | Commitment | Flexibility |
|------|----------|------------|-------------|
| 1-year, no upfront | ~25% | $/hr usage | Any Fargate region, OS, CPU |
| 1-year, all upfront | ~30% | $/hr usage | Any Fargate region, OS, CPU |
| 3-year, no upfront | ~40% | $/hr usage | Any Fargate region, OS, CPU |
| 3-year, all upfront | ~50% | $/hr usage | Any Fargate region, OS, CPU |

Compute Savings Plans apply to Fargate, Lambda, and EC2, providing maximum flexibility.

## Cost Optimization Strategies

| Strategy | Savings | Effort |
|----------|---------|--------|
| Right-size CPU/memory | 10-40% | Low -- analyze CloudWatch metrics |
| ARM/Graviton processors | 20% | Medium -- rebuild images for ARM |
| Fargate Spot for batch | Up to 70% | Medium -- add interruption handling |
| Compute Savings Plans | 25-50% | Low -- commit to usage level |
| Scale to zero off-hours | 30-50% | Medium -- scheduled scaling policies |
| Reduce idle tasks | Variable | Low -- review minimum task counts |

## Common Mistakes

### Wrong

Running steady-state production services on Fargate on-demand without Savings Plans.

### Correct

Purchase Compute Savings Plans for baseline capacity. Use Fargate Spot for burst/batch workloads. Right-size tasks using CloudWatch CPU/memory utilization data.

## Fargate vs EC2 Cost Breakpoint

Fargate typically costs 30-50% more than self-managed EC2 for steady workloads, but saves on operational overhead (patching, AMI updates, capacity planning). The breakpoint favors Fargate when:
- Team is small (< 3 infrastructure engineers)
- Workloads are bursty or variable
- Time-to-market matters more than raw compute cost

## Related

- [task-definitions](task-definitions.md)
- [ecs-vs-eks](ecs-vs-eks.md)
- [../patterns/auto-scaling](../patterns/auto-scaling.md)
