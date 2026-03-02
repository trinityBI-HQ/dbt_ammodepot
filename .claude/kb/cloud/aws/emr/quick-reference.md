# AWS EMR Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Deployment Modes

| Mode | Infrastructure | Scaling | Best For |
|------|---------------|---------|----------|
| EMR on EC2 | You manage clusters | Managed scaling | Long-running, complex workloads |
| EMR on EKS | Shared EKS clusters | Pod-based | K8s-native orgs, multi-tenant |
| EMR Serverless | Fully managed | Auto to zero | Batch jobs, variable workloads |

## EMR 7.x Releases

| Release | Spark | Iceberg | Hudi | Delta | Python |
|---------|-------|---------|------|-------|--------|
| 7.12.0 | 3.5.6 | 1.10.0 | 1.0.2 | 3.3.2 | 3.11 |
| 7.5.0 | 3.5.3 | 1.6.1 | 0.15 | 3.2.1 | 3.11 |
| 7.0.0 | 3.5.0 | 1.4.2 | 0.14 | 3.1.0 | 3.11 |

## Node Types (EC2 Mode)

| Node | Role | Min | Spot OK? |
|------|------|-----|----------|
| Master (Primary) | YARN RM, HDFS NN, drivers | 1 (or 3 HA) | No |
| Core | YARN NM, HDFS DN, executors | 1 | With caution |
| Task | Executors only, no HDFS | 0 | Yes (recommended) |

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `aws emr create-cluster --release-label emr-7.12.0 ...` | Create cluster |
| `aws emr add-steps --cluster-id j-XXX --steps ...` | Submit step |
| `aws emr list-clusters --active` | List running clusters |
| `aws emr describe-cluster --cluster-id j-XXX` | Cluster details |
| `aws emr terminate-clusters --cluster-ids j-XXX` | Terminate cluster |
| `aws emr ssh --cluster-id j-XXX --key-pair-file key.pem` | SSH to master |

## Instance Fleet Allocation

| Strategy | Description | Use When |
|----------|-------------|----------|
| `capacity-optimized` | Lowest interruption pools | Spot task nodes |
| `lowest-price` | Cheapest instance types | Cost-sensitive, risk-tolerant |
| `diversified` | Spread across pools | Balance cost and stability |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Ad-hoc Spark jobs, variable load | EMR Serverless |
| Long-running cluster, Hbase/Presto | EMR on EC2 |
| Kubernetes-native team | EMR on EKS |
| Sub-second Spark startup | EMR Serverless + pre-init workers |
| Cost-sensitive batch ETL | EMR on EC2 + Spot task nodes |
| Multi-tenant analytics | EMR on EKS (namespace isolation) |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use master node for heavy compute | Add task nodes (Spot) for executors |
| Store persistent data on HDFS | Use S3 via EMRFS for durability |
| Use single instance type in fleets | Diversify with 5-15 instance types |
| Skip managed scaling | Enable managed scaling for auto-resize |
| Run Spot on master/core nodes | Spot for task nodes only |
| Use old EMR 5.x/6.x for new clusters | Use EMR 7.12+ (Spark 3.5, Iceberg) |
| Hardcode cluster size | Use managed scaling with min/max bounds |

## IAM Roles

| Role | Purpose |
|------|---------|
| EMR Service Role | EMR service permissions (EC2, S3, CloudWatch) |
| EC2 Instance Profile | Permissions for cluster EC2 instances |
| Auto Scaling Role | CloudWatch metrics for scaling decisions |
| Runtime Role | Per-step/per-job IAM for Lake Formation |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/cluster-architecture.md` |
| Full Index | `index.md` |
