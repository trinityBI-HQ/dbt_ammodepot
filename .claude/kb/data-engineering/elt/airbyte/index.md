# Airbyte Knowledge Base

> **Purpose**: Open-source data integration platform for ELT workflows with 350+ connectors
> **Version**: 2.0.x (architecture overhaul, Oct 2025)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/connectors.md](concepts/connectors.md) | Sources, destinations, and connector types |
| [concepts/sync-modes.md](concepts/sync-modes.md) | Full refresh vs incremental sync strategies |
| [concepts/connections.md](concepts/connections.md) | Connection configuration and scheduling |
| [concepts/normalization.md](concepts/normalization.md) | Data transformation and typing/deduping |
| [concepts/python-cdk.md](concepts/python-cdk.md) | Connector Development Kit for custom connectors |
| [concepts/cloud-vs-oss.md](concepts/cloud-vs-oss.md) | Deployment options and feature comparison |
| [concepts/airbyte-api.md](concepts/airbyte-api.md) | REST API for programmatic control |
| [concepts/catalog-schema.md](concepts/catalog-schema.md) | Schema discovery and stream configuration |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/terraform-orchestration.md](patterns/terraform-orchestration.md) | Infrastructure as Code with Terraform provider |
| [patterns/api-triggered-syncs.md](patterns/api-triggered-syncs.md) | Orchestrating syncs with Dagster/Prefect |
| [patterns/custom-python-connector.md](patterns/custom-python-connector.md) | Building REST API connectors with Python CDK |
| [patterns/incremental-dedup-pattern.md](patterns/incremental-dedup-pattern.md) | Implementing efficient incremental syncs |
| [patterns/multi-environment-setup.md](patterns/multi-environment-setup.md) | Dev/staging/prod environment management |
| [patterns/monitoring-observability.md](patterns/monitoring-observability.md) | Sync monitoring and alerting strategies |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Connectors** | Pre-built integrations for 350+ sources and destinations |
| **Sync Modes** | Full Refresh (all data) vs Incremental (new/changed data only) |
| **Connections** | Configured syncs between source and destination |
| **Normalization** | Transform JSON blobs into typed, relational tables |
| **Python CDK** | Framework for building custom connectors (incl. Stream Templates) |
| **Catalog** | Schema metadata defining available streams and fields |
| **Streams** | Individual data tables or API endpoints to sync |
| **Cursors** | Timestamp/ID fields used for incremental syncs |
| **Data Activation** | Reverse ETL to push warehouse data to CRMs/marketing tools (2.0 GA) |
| **AI Connections** | AI-configured connections for automated setup (Dec 2025) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/connectors.md, concepts/sync-modes.md, concepts/connections.md |
| **Intermediate** | concepts/normalization.md, patterns/incremental-dedup-pattern.md, patterns/terraform-orchestration.md |
| **Advanced** | concepts/python-cdk.md, patterns/custom-python-connector.md, patterns/api-triggered-syncs.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| data-engineer | patterns/terraform-orchestration.md, patterns/incremental-dedup-pattern.md | Production ELT pipelines |
| devops-engineer | concepts/cloud-vs-oss.md, patterns/multi-environment-setup.md | Deploy and manage Airbyte |
| python-developer | concepts/python-cdk.md, patterns/custom-python-connector.md | Build custom connectors |
| pipeline-architect | patterns/api-triggered-syncs.md, patterns/monitoring-observability.md | Orchestrate data workflows |

---

## Project Context

This KB supports data integration workflows using Airbyte:
- ELT (Extract, Load, Transform) pipelines with 350+ pre-built connectors
- **Airbyte 2.0** (Oct 2025): 4-6x faster syncs, Data Activation GA, Enterprise Flex
- Flexible sync modes (full refresh, incremental append, incremental dedup)
- Custom connector development with Python CDK and Stream Templates (v1.7+)
- Infrastructure as Code with Terraform provider
- API-driven orchestration with Dagster, Prefect, or Airflow
- Cloud, OSS, Enterprise, and **Enterprise Flex** (hybrid) deployment options
- AI-configured connections for automated setup (Dec 2025)
- Normalization using Typing and Deduping (Destinations V2)
