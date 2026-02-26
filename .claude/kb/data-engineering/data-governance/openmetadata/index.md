# OpenMetadata Knowledge Base

> **Purpose**: Open-source metadata platform for data discovery, lineage, quality, governance, and observability
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/architecture.md](concepts/architecture.md) | Server components, metadata store, search engine, API layer |
| [concepts/data-assets.md](concepts/data-assets.md) | Tables, topics, dashboards, pipelines, ML models, APIs, storage |
| [concepts/metadata-ingestion.md](concepts/metadata-ingestion.md) | Connectors, ingestion framework, workflows, scheduling |
| [concepts/data-lineage.md](concepts/data-lineage.md) | Automated lineage, manual lineage, column-level lineage |
| [concepts/data-quality.md](concepts/data-quality.md) | Test suites, profiler, custom tests, data quality framework |
| [concepts/governance-classification.md](concepts/governance-classification.md) | Tags, tiers, glossaries, policies, roles, teams |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/deployment-patterns.md](patterns/deployment-patterns.md) | Docker Compose, Kubernetes/Helm, bare metal, production setup |
| [patterns/ingestion-patterns.md](patterns/ingestion-patterns.md) | Connector configuration, scheduling, custom connectors |
| [patterns/governance-workflows.md](patterns/governance-workflows.md) | Classification, ownership, glossaries, approval workflows |
| [patterns/integration-patterns.md](patterns/integration-patterns.md) | Integration with Airflow, dbt, Dagster, Great Expectations |

### Reference

| File | Purpose |
|------|---------|
| [quick-reference.md](quick-reference.md) | Fast lookup tables for connectors, APIs, and CLI |

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Metadata Store** | MySQL-backed entity store for all metadata entities and relationships |
| **Search Engine** | Elasticsearch/OpenSearch index for data discovery and exploration |
| **Ingestion Framework** | Python-based framework with 80+ connectors for metadata extraction |
| **Data Quality** | Built-in profiler and test suites for no-code data quality testing |
| **Governance** | Glossaries, classification tags, tiers, policies, and RBAC |
| **Lineage** | Table-level and column-level lineage across pipelines and tools |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/architecture.md, concepts/data-assets.md |
| **Intermediate** | concepts/metadata-ingestion.md, patterns/deployment-patterns.md |
| **Advanced** | patterns/integration-patterns.md, patterns/governance-workflows.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dagster-expert | patterns/integration-patterns.md | Dagster lineage in OpenMetadata |
| dbt-expert | patterns/integration-patterns.md | dbt metadata ingestion and lineage |
| kb-architect | All files | KB creation and maintenance |
