# OpenMetadata Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Architecture Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| API Server | Java (Dropwizard) | REST API, entity management, auth |
| Entity Store | MySQL | Metadata entities, relationships, versions |
| Search Engine | Elasticsearch/OpenSearch | Discovery, indexing, full-text search |
| Ingestion Framework | Python | Connectors, workflows, scheduling |
| UI | React/TypeScript | Discovery, governance, collaboration |

## Connector Categories

| Category | Examples | Count |
|----------|----------|-------|
| Databases | Snowflake, BigQuery, PostgreSQL, Redshift, MySQL | 40+ |
| Dashboards | Tableau, Power BI, Looker, Metabase, Grafana | 10+ |
| Messaging | Kafka, Redpanda, Kinesis | 5+ |
| Pipelines | Airflow, dbt Cloud, Dagster, Fivetran | 8+ |
| ML Models | MLflow, SageMaker | 3+ |
| Storage | S3, GCS, ADLS | 3+ |

## Workflow Types

| Workflow | Purpose | Output |
|----------|---------|--------|
| Metadata | Structural metadata extraction | Tables, schemas, columns |
| Usage | Query execution patterns | Popular tables, queries |
| Lineage | Data dependencies tracking | Table/column lineage |
| Profiler | Data statistics and sampling | Column stats, distributions |
| Data Quality | Test execution and results | Pass/fail, incidents |
| dbt | dbt artifact ingestion | Models, tests, lineage |

## Governance Features

| Feature | Purpose |
|---------|---------|
| Glossary | Business term definitions, hierarchy, synonyms |
| Classification | Tag groups (PII, Sensitive, Tier 1-5) |
| Policies | Access control rules based on tags/roles |
| Ownership | Team/user asset assignment |
| Tiers | Data importance levels (Tier 1 = critical) |

## Common API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/tables` | GET/POST | List or create tables |
| `/api/v1/tables/{id}/lineage` | GET | Get table lineage |
| `/api/v1/services/databaseServices` | GET/POST | Manage database services |
| `/api/v1/glossaries` | GET/POST | Manage glossaries |
| `/api/v1/classifications` | GET/POST | Manage classifications |
| `/api/v1/testSuites` | GET/POST | Manage test suites |

## Python SDK Quick Start

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata
from metadata.generated.schema.entity.services.connections.metadata.openMetadataConnection import OpenMetadataConnection

config = OpenMetadataConnection(hostPort="http://localhost:8585/api", authProvider="openmetadata", securityConfig={"jwtToken": "<token>"})
client = OpenMetadata(config)
```

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Simple data catalog | OpenMetadata UI discovery |
| Automated lineage | Ingestion framework connectors |
| Data quality testing | Built-in test suites + profiler |
| Business glossary | Governance > Glossary |
| Compliance tagging | Classification + Policies |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Skip Elasticsearch setup | Always deploy with search engine |
| Use root credentials for connectors | Create dedicated read-only service accounts |
| Ignore ingestion scheduling | Set up cron-based recurring workflows |
| Skip ownership assignment | Assign owners during initial metadata ingestion |

## Related Documentation

| Topic | Path |
|-------|------|
| Architecture | `concepts/architecture.md` |
| Full Index | `index.md` |
| Deployment | `patterns/deployment-patterns.md` |
| Integrations | `patterns/integration-patterns.md` |
