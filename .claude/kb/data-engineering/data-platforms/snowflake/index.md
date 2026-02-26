# Snowflake Knowledge Base

> **Purpose**: Cloud data warehouse platform with AI-powered analytics, scalable data engineering, and secure data sharing
> **MCP Validated**: 2026-02-25

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/virtual-warehouses.md](concepts/virtual-warehouses.md) | Compute clusters for query execution |
| [concepts/databases-schemas.md](concepts/databases-schemas.md) | Logical organization of data objects |
| [concepts/stages.md](concepts/stages.md) | Internal and external staging for data loading |
| [concepts/tables-views.md](concepts/tables-views.md) | Data storage structures and virtual tables |
| [concepts/variant-data.md](concepts/variant-data.md) | Semi-structured data with VARIANT type |
| [concepts/roles-privileges.md](concepts/roles-privileges.md) | RBAC security model and access control |
| [concepts/interactive-tables.md](concepts/interactive-tables.md) | Interactive Tables and Warehouses for sub-second latency (GA Dec 2025) |
| [concepts/cortex-code.md](concepts/cortex-code.md) | AI-native coding agent for data work (GA Feb 2026) |
| [concepts/openflow.md](concepts/openflow.md) | Managed Apache NiFi integration service (GA May 2025) |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/copy-into-loading.md](patterns/copy-into-loading.md) | Bulk data loading with COPY INTO |
| [patterns/snowpipe-streaming.md](patterns/snowpipe-streaming.md) | Continuous data ingestion |
| [patterns/semi-structured-queries.md](patterns/semi-structured-queries.md) | Querying JSON with FLATTEN and LATERAL |
| [patterns/performance-optimization.md](patterns/performance-optimization.md) | Clustering, caching, materialized views |
| [patterns/python-connector.md](patterns/python-connector.md) | Python SDK integration patterns |
| [patterns/spark-connector.md](patterns/spark-connector.md) | Apache Spark integration |
| [patterns/interactive-analytics.md](patterns/interactive-analytics.md) | Low-latency dashboards and API serving (GA Dec 2025) |
| [patterns/cortex-code-workflows.md](patterns/cortex-code-workflows.md) | AI-assisted data development workflows (GA Feb 2026) |
| [patterns/openflow-integration.md](patterns/openflow-integration.md) | Any-to-any data integration with Openflow (GA May 2025) |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for SQL syntax, sizing, and feature comparison

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Virtual Warehouses** | Compute clusters that execute SQL queries; scale independently from storage |
| **Micro-partitions** | Automatic columnar storage units (50-500MB) enabling pruning |
| **VARIANT** | Native data type for JSON, Avro, Parquet semi-structured data |
| **Zero-copy Cloning** | Instant table/database copies without duplicating storage |
| **Data Sharing** | Secure, live data access across Snowflake accounts |
| **Time Travel** | Query historical data up to 90 days for recovery and analysis |
| **Interactive Tables** | Row-oriented tables with built-in indexing for sub-second queries (GA Dec 2025) |
| **Interactive Warehouses** | Always-on compute with SSD caching for low-latency workloads (GA Dec 2025) |
| **Cortex AI** | Built-in AI functions: classify, transcribe, embed, similarity, sentiment, extract (GA Nov 2025) |
| **Cortex Code** | AI coding agent for data engineering, analytics, ML within Snowflake (CLI GA Feb 2026) |
| **Snowflake Intelligence** | Natural language querying via Cortex Analyst + Search + AI agents (GA Nov 2025) |
| **Openflow** | Managed Apache NiFi for any-to-any data integration; BYOC + SPCS (GA May 2025) |
| **Open Catalog / Polaris** | Managed REST-based Iceberg catalog with Delta Lake support, engine-agnostic |
| **Horizon Catalog** | Unified governance across clouds and open formats |
| **Dynamic Tables** | Declarative pipelines with incremental refresh, `CLUSTER BY` support (Nov 2025) |
| **Semantic Views** | Schema-level objects for natural language queries via Cortex Analyst (GA Oct 2025) |
| **Adaptive Compute** | Policy-driven, zero-ops compute that auto-adjusts to workload patterns (2025) |
| **Gen2 Warehouses** | 2.1x faster analytics; up to 300 clusters per multi-cluster warehouse (2025) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/databases-schemas.md, concepts/tables-views.md |
| **Intermediate** | patterns/copy-into-loading.md, concepts/stages.md |
| **Advanced** | patterns/performance-optimization.md, patterns/semi-structured-queries.md |
| **Interactive** | concepts/interactive-tables.md, patterns/interactive-analytics.md |
| **AI/ML** | concepts/cortex-code.md, patterns/cortex-code-workflows.md |
| **Integration** | concepts/openflow.md, patterns/openflow-integration.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| data-engineer | patterns/copy-into-loading.md, patterns/snowpipe-streaming.md | Data pipeline development |
| spark-specialist | patterns/spark-connector.md | Spark-Snowflake integration |
| python-developer | patterns/python-connector.md | Application development |
| analytics-engineer | patterns/interactive-analytics.md, concepts/interactive-tables.md | Low-latency dashboards |
| ai-developer | concepts/cortex-code.md, patterns/cortex-code-workflows.md | AI-assisted development |
| integration-engineer | concepts/openflow.md, patterns/openflow-integration.md | Data integration pipelines |
