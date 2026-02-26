# AWS S3 Tables Knowledge Base

> **Purpose**: Fully managed Apache Iceberg tables on S3 — analytics-optimized tabular storage
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/table-buckets-namespaces.md](concepts/table-buckets-namespaces.md) | Table buckets, namespaces, tables, ARNs |
| [concepts/iceberg-integration.md](concepts/iceberg-integration.md) | Apache Iceberg format, REST Catalog APIs, schema |
| [concepts/maintenance-compaction.md](concepts/maintenance-compaction.md) | Auto-compaction, snapshot management, file cleanup |
| [concepts/security-access.md](concepts/security-access.md) | IAM policies, table policies, encryption, Lake Formation |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/analytics-integration.md](patterns/analytics-integration.md) | Athena, Redshift, EMR, Glue Data Catalog setup |
| [patterns/data-lake-medallion.md](patterns/data-lake-medallion.md) | Medallion architecture with S3 Tables |
| [patterns/terraform-setup.md](patterns/terraform-setup.md) | IaC provisioning with Terraform |

---

## What is S3 Tables?

Amazon S3 Tables (GA December 2024) provides the **first cloud object store with built-in Apache Iceberg support**. Key differentiators:

| Feature | S3 Tables | Self-Managed Iceberg on S3 |
|---------|-----------|---------------------------|
| Query throughput | Up to 3x faster | Baseline |
| Transactions/sec | Up to 10x higher | Baseline |
| Compaction | Automatic (managed) | Manual / custom jobs |
| Snapshot management | Automatic | Manual |
| Catalog | Built-in via Glue Data Catalog | Self-managed |
| Storage type | Table buckets (dedicated) | General purpose buckets |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Table Bucket** | Dedicated bucket type for storing tables (up to 10 per region) |
| **Namespace** | Logical grouping within a table bucket (maps to Glue database) |
| **Table** | Apache Iceberg table stored as a subresource (up to 10,000 per bucket) |
| **Iceberg V3** | V3 format support with deletion vectors for row-level deletes (Nov 2025) |
| **Sort/Z-Order Compaction** | Automated or on-demand sort and z-order compaction (Jun 2025) |
| **Intelligent-Tiering** | Auto-tiering storage class for cost optimization (Dec 2025) |
| **Maintenance** | Auto-compaction + snapshot management (enabled by default) |
| **Glue Integration** | `s3tablescatalog` federated catalog in Glue Data Catalog |
| **Replication** | Cross-region/account read-only replicas (Dec 2025) |
| **SageMaker Studio** | Unified Studio integration for notebook-based analytics |

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/table-buckets-namespaces.md, concepts/iceberg-integration.md |
| **Intermediate** | concepts/maintenance-compaction.md, concepts/security-access.md |
| **Advanced** | patterns/analytics-integration.md, patterns/data-lake-medallion.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| aws-lambda-architect | concepts/security-access.md | IAM for S3 Tables access |
| spark-specialist | patterns/analytics-integration.md | Spark + Iceberg queries |
| lakeflow-architect | patterns/data-lake-medallion.md | Medallion on managed Iceberg |
| infra-deployer | patterns/terraform-setup.md | Terraform provisioning |

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| S3 | `../s3/` | Underlying storage; S3 Tables is a table bucket type |
| Terraform | `../../../devops-sre/iac/terraform/` | IaC for S3 Tables resources |
| Dagster | `../../../data-engineering/orchestration/dagster/` | Orchestrate analytics pipelines |
| dbt | `../../../data-engineering/transformation/dbt/` | Transform data in Iceberg tables |
