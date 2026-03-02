# Onehouse Knowledge Base

> **Purpose**: Fully managed universal data lakehouse platform built on Apache Hudi with automated table management, incremental ETL, and multi-engine interoperability
> **MCP Validated**: 2026-03-01

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/platform-architecture.md](concepts/platform-architecture.md) | Core architecture: control plane, data plane, OCR, and product modules |
| [concepts/oneflow-ingestion.md](concepts/oneflow-ingestion.md) | Managed CDC, streaming, and file ingestion into lakehouse tables |
| [concepts/table-optimizer.md](concepts/table-optimizer.md) | Automated compaction, clustering, and cleaning for Hudi/Iceberg/Delta |
| [concepts/onesync-catalog.md](concepts/onesync-catalog.md) | Multi-catalog sync with Snowflake, Databricks, BigQuery, and Glue |
| [concepts/xtable-interoperability.md](concepts/xtable-interoperability.md) | Apache XTable cross-format metadata translation (Hudi/Iceberg/Delta) |
| [concepts/lakeview-observability.md](concepts/lakeview-observability.md) | Free lakehouse observability: metrics, alerts, and table health monitoring |
| [concepts/compute-runtime.md](concepts/compute-runtime.md) | Onehouse Compute Runtime (OCR): serverless Spark with Quanton engine |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/cdc-ingestion-pipeline.md](patterns/cdc-ingestion-pipeline.md) | End-to-end CDC from RDBMS to analytics-ready lakehouse tables |
| [patterns/multi-engine-query.md](patterns/multi-engine-query.md) | Write once with Hudi, query from Snowflake/Databricks/BigQuery via XTable |
| [patterns/table-optimization.md](patterns/table-optimization.md) | Configure compaction, clustering, and cleaning for optimal performance |
| [patterns/incremental-etl.md](patterns/incremental-etl.md) | Bronze-to-silver incremental transformations with managed pipelines |

### Specs (Machine-Readable)

| File | Purpose |
|------|---------|
| [specs/product-components.yaml](specs/product-components.yaml) | Complete product module registry with features and integrations |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for products, integrations, and decision matrices

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Universal Data Lakehouse** | Ingest once, query anywhere across any engine, format, or catalog |
| **OneFlow** | Managed ingestion from databases (CDC), Kafka streams, and cloud storage files |
| **Table Optimizer** | Automated compaction, clustering, and cleaning across Hudi, Iceberg, Delta |
| **OneSync** | Multi-catalog sync to Snowflake, Databricks Unity, BigQuery, Glue, Hive |
| **Apache XTable** | Open-source cross-format interoperability via metadata translation |
| **LakeView** | Free observability tool analyzing table metadata for health and optimization |
| **OCR (Compute Runtime)** | Serverless Spark runtime with Quanton engine for lakehouse workloads |
| **LakeBase** | Foundation lakehouse layer for data storage and management |
| **Quanton** | SQL and Spark execution engine on OCR with 2-30x query acceleration |
| **BYOC (Bring Your Own Cloud)** | Data plane runs in customer VPC; data never leaves customer storage |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/platform-architecture.md, concepts/oneflow-ingestion.md |
| **Intermediate** | concepts/table-optimizer.md, patterns/cdc-ingestion-pipeline.md |
| **Advanced** | concepts/xtable-interoperability.md, patterns/multi-engine-query.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| data-engineer | patterns/cdc-ingestion-pipeline.md, patterns/incremental-etl.md | Lakehouse pipeline development |
| spark-specialist | concepts/compute-runtime.md | OCR and Spark workload optimization |
| snowflake-expert | concepts/onesync-catalog.md, patterns/multi-engine-query.md | Snowflake-Onehouse integration |
| medallion-architect | patterns/incremental-etl.md, concepts/oneflow-ingestion.md | Bronze/Silver/Gold lakehouse design |
