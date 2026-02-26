# Architecture

> **Purpose**: OpenMetadata server components, metadata store, search engine, and API layer
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

OpenMetadata has a streamlined architecture with four core components: the API server, Entity Store (MySQL), Search Engine (Elasticsearch/OpenSearch), and Ingestion Framework. The Java-based backend exposes a REST API that powers the React/TypeScript UI and Python ingestion framework.

## The Architecture

```text
+------------------+     +------------------+     +-------------------+
|   React/TS UI    |     |  Python SDK /    |     |  External Tools   |
|  (Discovery,     |     |  Ingestion       |     |  (Airflow, dbt,   |
|   Governance)    |     |  Framework       |     |   Dagster, etc.)  |
+--------+---------+     +--------+---------+     +--------+----------+
         |                        |                         |
         +----------+-------------+-------------------------+
                    |
         +----------v-----------+
         |   REST API Server    |
         |  (Java/Dropwizard)   |
         |  - Entity CRUD       |
         |  - Auth (JWT/SSO)    |
         |  - Event System      |
         +----+------------+----+
              |            |
    +---------v---+  +-----v-----------+
    | Entity Store|  | Search Engine   |
    | (MySQL)     |  | (Elasticsearch  |
    | - Entities  |  |  /OpenSearch)   |
    | - Relations |  | - Full-text     |
    | - Versions  |  | - Discovery     |
    +---------+---+  +-----+-----------+
              |            |
         +----v------------v----+
         |   Event System       |
         |  (Change Events)     |
         |  - Webhooks          |
         |  - Elasticsearch     |
         |    re-indexing        |
         +-----------------------+
```

## Component Details

| Component | Technology | Responsibility |
|-----------|-----------|----------------|
| API Server | Java 17, Dropwizard | REST endpoints, auth, event processing |
| Entity Store | MySQL 8.x | Entities, relationships, version history |
| Search Engine | Elasticsearch 8.x / OpenSearch | Indexing, full-text search, discovery |
| Ingestion Framework | Python 3.9+ | Connector execution, metadata extraction |
| UI | React, TypeScript | User interface for all platform features |

## API Server

The API is the central pillar. All metadata operations go through the REST API, including UI interactions, SDK calls, and ingestion workflows. Key features:

- **Entity CRUD**: Create, read, update, delete for all entity types
- **Authentication**: JWT tokens, SSO (Google, Okta, Azure AD, Auth0)
- **Authorization**: Role-Based Access Control (RBAC)
- **Event System**: Change events propagated to Elasticsearch and webhooks
- **Versioning**: All entity changes are tracked with full version history

## Entity Store (MySQL)

MySQL stores the real-time state of all entities and relationships:

- **Entities**: Tables, databases, schemas, users, teams, glossaries
- **Relationships**: Ownership, lineage, tags, follows
- **Versions**: Every metadata change creates a new version
- **JSON Storage**: Entity details stored as JSON within MySQL columns

## Search Engine

Elasticsearch (or OpenSearch) indexes all metadata for fast discovery:

- **Full-text search** across entity names, descriptions, columns, tags
- **Faceted filtering** by service, database, schema, owner, tags, tier
- **Ranking** based on usage, tier, and activity signals

## Event System

Change events power downstream integrations:

- Entity creation, update, and deletion events
- Webhook notifications to Slack, Teams, email
- Automatic Elasticsearch re-indexing on entity changes
- Alerts for data quality failures and SLA breaches

## Related

- [Data Assets](../concepts/data-assets.md)
- [Metadata Ingestion](../concepts/metadata-ingestion.md)
- [Deployment Patterns](../patterns/deployment-patterns.md)
