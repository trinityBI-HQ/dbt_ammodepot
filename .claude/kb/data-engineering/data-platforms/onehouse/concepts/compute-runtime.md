# Onehouse Compute Runtime (OCR)

> **Purpose**: Serverless Spark-based compute runtime for lakehouse ingestion, ETL, and table optimization workloads
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

The Onehouse Compute Runtime (OCR) is a serverless execution engine launched in January 2025 that runs all Onehouse workloads -- ingestion, incremental ETL, and table optimizations -- inside the customer's VPC. OCR uses Spark-based serverless compute with elastic scaling, deep integration between Spark and lakehouse storage, and a purpose-built query engine called Quanton for SQL and Spark workloads. It is 100% compatible with open-source Apache Spark, enabling migration on and off without lock-in.

## The Pattern

```text
OCR Architecture
================

+-----------------------------------------------------+
| Onehouse Compute Runtime (Customer VPC)              |
|                                                      |
|  +------------------+  +------------------------+   |
|  | Serverless       |  | Adaptive Workload      |   |
|  | Compute Manager  |  | Optimizer              |   |
|  |                  |  |                         |   |
|  | - Auto-scaling   |  | - Multiplexed jobs     |   |
|  | - Multi-cluster  |  | - Lag-aware latency    |   |
|  | - Auto-provision |  | - Write/query balance  |   |
|  +------------------+  +------------------------+   |
|                                                      |
|  +------------------+  +------------------------+   |
|  | Quanton Engine   |  | High-Performance       |   |
|  |                  |  | Lakehouse I/O          |   |
|  | - SQL execution  |  |                         |   |
|  | - Spark jobs     |  | - Vectorized merging   |   |
|  | - 100% OSS Spark |  | - Parallel pipelining  |   |
|  |   compatible     |  | - Optimized storage    |   |
|  +------------------+  +------------------------+   |
+-----------------------------------------------------+
```

## Quick Reference

| Component | Purpose | Key Benefit |
|-----------|---------|-------------|
| Serverless Compute Manager | Cluster provisioning and scaling | Zero cluster management |
| Adaptive Workload Optimizer | Job scheduling and resource allocation | Optimal cost/performance |
| Quanton Engine | SQL and Spark execution | 2-30x query acceleration |
| High-Performance I/O | Vectorized reads/writes | Faster ingestion and queries |

| Metric | Performance |
|--------|-------------|
| Query acceleration | 2-30x faster vs. standard Spark |
| Cost savings | 20-80% vs. always-on clusters |
| Spark compatibility | 100% OSS Apache Spark compatible |
| Scaling | Elastic auto-scale up and down |
| Deployment | BYOC in customer VPC |

| Workload Type | OCR Handles |
|---------------|-------------|
| Data ingestion | OneFlow CDC, streaming, file ingestion |
| Table optimization | Compaction, clustering, cleaning |
| Incremental ETL | Bronze-to-silver transformations |
| Ad-hoc SQL | Quanton-powered SQL queries |
| Custom Spark | User-defined Spark jobs |

## Common Mistakes

### Wrong

```text
Provisioning dedicated always-on EMR/Dataproc clusters
for each lakehouse maintenance task (compaction, clustering).
Manually tuning Spark autoscaler for lakehouse workloads.
```

### Correct

```text
OCR's Serverless Compute Manager is purpose-built for
lakehouse storage patterns. It handles cluster lifecycle,
scaling, and job scheduling automatically. The Adaptive
Workload Optimizer multiplexes jobs across shared clusters,
balancing latency requirements with cost efficiency.
```

## Related

- [Platform Architecture](../concepts/platform-architecture.md)
- [Table Optimizer](../concepts/table-optimizer.md)
- [Table Optimization Pattern](../patterns/table-optimization.md)
