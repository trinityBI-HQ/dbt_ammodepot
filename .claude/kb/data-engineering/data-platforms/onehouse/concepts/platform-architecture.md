# Platform Architecture

> **Purpose**: Core architecture of Onehouse: control plane, data plane, product modules, and deployment model
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

Onehouse is a fully managed universal data lakehouse platform built on Apache Hudi. It uses a split-plane architecture where the control plane runs in Onehouse's cloud while the data plane (compute and storage) runs inside the customer's VPC. This BYOC (Bring Your Own Cloud) model ensures data never leaves customer infrastructure while Onehouse manages orchestration, optimization, and metadata services.

## The Pattern

```text
+--------------------------------------------------+
|              ONEHOUSE CONTROL PLANE               |
|  (Hosted by Onehouse - manages orchestration)     |
|                                                   |
|  +-----------+  +-----------+  +-----------+      |
|  | Pipeline  |  | Table     |  | Catalog   |      |
|  | Manager   |  | Optimizer |  | Sync      |      |
|  +-----------+  +-----------+  +-----------+      |
|  +-----------+  +-----------+                     |
|  | LakeView  |  | Scheduler |                     |
|  | (Free)    |  |           |                     |
|  +-----------+  +-----------+                     |
+--------------------------------------------------+
           |              |              |
           v              v              v
+--------------------------------------------------+
|              CUSTOMER DATA PLANE (VPC)            |
|  (Runs in customer AWS / GCP / Azure)             |
|                                                   |
|  +-----------+  +-----------+  +-----------+      |
|  | OCR       |  | Spark     |  | Storage   |      |
|  | Compute   |  | Clusters  |  | (S3/GCS)  |      |
|  +-----------+  +-----------+  +-----------+      |
|                                                   |
|  Data Sources:  RDBMS | Kafka | Cloud Files       |
+--------------------------------------------------+
           |              |              |
           v              v              v
+--------------------------------------------------+
|              QUERY ENGINES (Read Access)           |
|  Snowflake | Databricks | BigQuery | Athena       |
|  Trino | Redshift | ClickHouse | Spark            |
+--------------------------------------------------+
```

## Quick Reference

| Component | Location | Purpose |
|-----------|----------|---------|
| Control Plane | Onehouse cloud | Orchestration, scheduling, metadata management |
| Data Plane | Customer VPC | Compute (OCR/Spark), storage (S3/GCS/ADLS) |
| OneFlow | Control + Data | Managed ingestion pipelines |
| Table Optimizer | Control + Data | Automated compaction, clustering, cleaning |
| OneSync | Control Plane | Catalog sync to Snowflake, Databricks, BigQuery |
| LakeView | Control Plane | Free metadata-only observability |
| OCR | Data Plane | Serverless Spark compute runtime |
| LakeBase | Data Plane | Foundation lakehouse storage layer |

## Common Mistakes

### Wrong

```text
Assuming Onehouse stores or accesses your raw data files.
Data is read by Onehouse for processing outside the customer VPC.
```

### Correct

```text
Onehouse operates in BYOC mode. The data plane runs inside your VPC.
Only metadata (not Parquet/data files) is sent to the control plane
for orchestration, monitoring (LakeView), and catalog sync.
SOC2 Types I & II and PCI DSS compliant.
```

## Related

- [OneFlow Ingestion](../concepts/oneflow-ingestion.md)
- [Compute Runtime](../concepts/compute-runtime.md)
- [CDC Ingestion Pipeline](../patterns/cdc-ingestion-pipeline.md)
