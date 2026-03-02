# EMR Serverless

> **Purpose**: Fully serverless Spark and Hive execution with automatic scaling
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

EMR Serverless runs Apache Spark and Hive workloads without provisioning or managing clusters. You create an application, submit jobs, and EMR Serverless automatically provisions, scales, and releases resources. It scales to zero when idle, so you only pay for compute time used.

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Application** | Container for job runs, defines framework (Spark/Hive) and config |
| **Job Run** | A single Spark or Hive job submitted to an application |
| **Pre-initialized Capacity** | Warm pool of workers for sub-second job startup |
| **Worker** | Compute unit (driver or executor) with configurable vCPUs and memory |
| **Release Label** | EMR version (e.g., `emr-7.12.0`) defining framework versions |

## Architecture

```
Submit Job Run
      │
      v
┌─────────────────────────────────────────┐
│  EMR Serverless Application             │
│  ┌──────────────────────────────────┐   │
│  │  Pre-initialized Workers (warm)  │   │
│  │  Driver: 2 workers               │   │
│  │  Executor: 10 workers            │   │
│  └──────────────────────────────────┘   │
│                                         │
│  Auto-scales executors up/down          │
│  Scales to zero when no jobs running    │
└─────────────────────────────────────────┘
      │           │
      v           v
   S3 (I/O)    Glue Catalog
```

## Create Application and Submit Job

```bash
# 1. Create application
aws emr-serverless create-application \
  --name spark-analytics \
  --release-label emr-7.12.0 \
  --type SPARK \
  --maximum-capacity '{
    "cpu": "400 vCPU",
    "memory": "3000 GB"
  }'

# 2. Submit job run
aws emr-serverless start-job-run \
  --application-id app-xxxxx \
  --execution-role-arn arn:aws:iam::role/EMRServerlessRole \
  --job-driver '{
    "sparkSubmit": {
      "entryPoint": "s3://scripts/etl.py",
      "entryPointArguments": ["--date", "2026-03-01"],
      "sparkSubmitParameters": "--conf spark.executor.cores=4 --conf spark.executor.memory=16g"
    }
  }' \
  --configuration-overrides '{
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {
        "logUri": "s3://logs/emr-serverless/"
      }
    }
  }'
```

## Pre-initialized Capacity

Keeps workers warm for instant job startup (eliminates cold start):

```bash
aws emr-serverless update-application \
  --application-id app-xxxxx \
  --initial-capacity '{
    "DRIVER": {
      "workerCount": 2,
      "workerConfiguration": {
        "cpu": "2 vCPU",
        "memory": "4 GB"
      }
    },
    "EXECUTOR": {
      "workerCount": 10,
      "workerConfiguration": {
        "cpu": "4 vCPU",
        "memory": "16 GB"
      }
    }
  }'
```

**Cost note**: Pre-initialized workers incur charges even when idle. Use for latency-sensitive jobs only.

## Worker Sizes

| Size | vCPU | Memory | Use Case |
|------|------|--------|----------|
| Small | 1 | 4 GB | Light transforms |
| Medium | 2 | 8 GB | Standard ETL |
| Large | 4 | 16 GB | Joins, aggregations |
| XLarge | 8 | 32 GB | Memory-heavy |
| 4XLarge | 32 | 120 GB | Intensive workloads |

Custom sizes supported. Disk auto-managed since Dec 2025 (no local storage provisioning needed).

## When to Use

| Scenario | Serverless | EC2 |
|----------|:----------:|:---:|
| Variable batch workloads | Best | OK |
| Scale to zero between jobs | Best | -- |
| Long-running services (Presto/HBase) | -- | Best |
| Fine-grained instance control | -- | Best |

**Supported**: Apache Spark (PySpark/Scala), Apache Hive (on Tez). **Not supported**: Presto, HBase, Flink.

## Common Mistakes

### Wrong

```bash
# No maximum capacity -- risk of runaway costs
aws emr-serverless create-application \
  --name app --release-label emr-7.12.0 --type SPARK
```

### Correct

```bash
# Always set maximum capacity limits
aws emr-serverless create-application \
  --name app --release-label emr-7.12.0 --type SPARK \
  --maximum-capacity '{"cpu": "200 vCPU", "memory": "1000 GB"}'
```

## Related

- [Cluster Architecture](cluster-architecture.md) -- EC2 mode comparison
- [Cost Optimization](../patterns/cost-optimization.md) -- Serverless cost strategies
- [Spark Submit Patterns](../patterns/spark-submit-patterns.md) -- Job submission
