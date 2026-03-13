# AWS EMR Knowledge Base

> **Purpose**: Managed big data platform -- Apache Spark, Hive, Presto on EC2, EKS, or Serverless
> **MCP Validated**: 2026-03-01

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/cluster-architecture.md](concepts/cluster-architecture.md) | Master/core/task nodes, instance groups vs fleets, YARN |
| [concepts/emr-on-eks.md](concepts/emr-on-eks.md) | Virtual clusters, managed endpoints, job runs on EKS |
| [concepts/emr-serverless.md](concepts/emr-serverless.md) | Serverless mode, auto-scaling, pre-initialized workers |
| [concepts/spark-on-emr.md](concepts/spark-on-emr.md) | EMR-optimized Spark runtime, Glue Catalog, table formats |
| [concepts/security.md](concepts/security.md) | IAM roles, Lake Formation, Kerberos, encryption |
| [concepts/storage-options.md](concepts/storage-options.md) | EMRFS, S3, HDFS, EBS, instance store |
| [patterns/cluster-provisioning.md](patterns/cluster-provisioning.md) | Terraform/CLI cluster creation, bootstrap actions |
| [patterns/spark-submit-patterns.md](patterns/spark-submit-patterns.md) | Step API, spark-submit, EMR Steps, job orchestration |
| [patterns/cost-optimization.md](patterns/cost-optimization.md) | Spot instances, managed scaling, Graviton, auto-termination |
| [patterns/integration-patterns.md](patterns/integration-patterns.md) | Glue Catalog, Step Functions, Airflow/Dagster, Lake Formation |
| [quick-reference.md](quick-reference.md) | Fast lookup tables |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **EMR on EC2** | Traditional managed clusters with master, core, and task nodes |
| **EMR on EKS** | Run Spark jobs on existing EKS clusters via virtual clusters |
| **EMR Serverless** | Fully serverless -- no cluster management, auto-scales to zero |
| **EMR Runtime** | Optimized Spark runtime, 4.5x faster than open-source Spark 3.5 |
| **EMRFS** | S3 as native filesystem, replacing HDFS for persistent storage |
| **Managed Scaling** | Automatic cluster resize based on workload metrics |
| **Instance Fleets** | Up to 30 instance types per fleet with allocation strategies |
| **EMR 7.12** | Latest: Spark 3.5.6, Iceberg 1.10.0, Hudi 1.0.2 |

## Architecture

```
Data Sources              EMR Deployment Modes           Consumers
-----------         ┌───────────────────────────┐       ---------
S3 (data lake) ---->│  EMR on EC2 (managed)     │-----> Athena
RDS/JDBC     ------>│  EMR on EKS (virtual)     │-----> Redshift/S3
Kafka/Kinesis ----->│  EMR Serverless (no infra)│-----> SageMaker/BI
                    └───────────────────────────┘
                        Glue Catalog | Lake Formation
```

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/cluster-architecture.md, concepts/storage-options.md |
| **Intermediate** | concepts/spark-on-emr.md, patterns/cluster-provisioning.md |
| **Advanced** | concepts/emr-serverless.md, concepts/emr-on-eks.md, patterns/cost-optimization.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| spark-specialist | concepts/spark-on-emr.md | Spark tuning on EMR |
| spark-performance-analyzer | patterns/cost-optimization.md | EMR performance profiling |
| aws-deployer | patterns/cluster-provisioning.md | EMR infrastructure deployment |
| ai-data-engineer | patterns/integration-patterns.md | Pipeline design with EMR |

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| AWS S3 | `../s3/` | Primary storage for EMR data |
| AWS Glue | `../glue/` | Data Catalog as metastore |
| AWS IAM | `../iam/` | IAM roles for EMR service and EC2 profiles |
| Terraform | `../../devops-sre/iac/terraform/` | IaC for EMR provisioning |
| Dagster | `../../data-engineering/orchestration/dagster/` | Orchestrate EMR jobs |
