# Data Assets

> **Purpose**: Entity types in OpenMetadata -- tables, topics, dashboards, pipelines, ML models, APIs, and storage
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

OpenMetadata models all metadata as typed entities organized under services. Each entity type captures domain-specific metadata while sharing common features like ownership, tags, descriptions, lineage, and version history. As of v1.5+, APIs are also first-class metadata assets.

## Entity Hierarchy

```text
Service (Database / Dashboard / Messaging / Pipeline / ML / Storage / API)
  +-- Database
  |     +-- Schema
  |           +-- Table
  |           |     +-- Column (name, type, constraints, tags, description)
  |           +-- Stored Procedure
  +-- Dashboard
  |     +-- Chart
  +-- Topic (Kafka, Redpanda)
  +-- Pipeline (Airflow DAG, Dagster Job)
  |     +-- Task
  +-- ML Model
  +-- Container (S3 bucket, GCS bucket)
  +-- API Collection
        +-- API Endpoint (request/response schemas)
```

## Core Entity Types

| Entity | Service Type | Key Metadata |
|--------|-------------|-------------|
| Table | Database | Columns, constraints, profiler stats, sample data |
| Topic | Messaging | Schema (Avro/JSON), partitions, replication |
| Dashboard | Dashboard | Charts, data models, usage metrics |
| Pipeline | Pipeline | Tasks, schedule, status, upstream/downstream |
| ML Model | ML Model | Algorithm, features, hyperparameters, metrics |
| Container | Storage | Objects, data model, file formats, size |
| API Endpoint | API | Request/response schemas, methods, lineage |

## Common Entity Properties

Every entity in OpenMetadata shares these cross-cutting features:

- **Ownership**: Assigned to a user or team
- **Description**: Markdown-formatted documentation
- **Tags**: Classification tags (PII, Sensitive, Tier)
- **Glossary Terms**: Business terminology links
- **Lineage**: Upstream and downstream dependencies
- **Version History**: Full audit trail of metadata changes
- **Followers**: Users interested in entity changes
- **Votes**: Upvotes/downvotes for relevance ranking

## Table Entity Details

Tables are the most common entity type with rich metadata:

```json
{
  "name": "customers",
  "database": "analytics_db",
  "databaseSchema": "public",
  "columns": [
    {
      "name": "customer_id",
      "dataType": "INT",
      "constraint": "PRIMARY_KEY",
      "description": "Unique customer identifier"
    },
    {
      "name": "email",
      "dataType": "VARCHAR",
      "tags": [{"tagFQN": "PII.Sensitive"}]
    }
  ],
  "tableType": "Regular",
  "serviceType": "Snowflake"
}
```

## Service Types

| Service Type | Examples | Entity Created |
|-------------|----------|---------------|
| DatabaseService | Snowflake, BigQuery, PostgreSQL | Tables, Schemas, Databases |
| DashboardService | Tableau, Power BI, Looker | Dashboards, Charts |
| MessagingService | Kafka, Redpanda, Kinesis | Topics |
| PipelineService | Airflow, Dagster, dbt Cloud | Pipelines, Tasks |
| MlModelService | MLflow, SageMaker | ML Models |
| StorageService | S3, GCS, ADLS | Containers |
| ApiService | REST APIs (OpenAPI) | API Endpoints |

## Metrics Entity (v1.6+)

OpenMetadata 1.6 introduced the Metric entity for documenting business metrics:

- Calculation formulas in SQL, Python, or LaTeX
- Lineage from source data to metric
- Owner and stakeholder assignment
- Version history for metric definitions

## Related

- [Architecture](../concepts/architecture.md)
- [Metadata Ingestion](../concepts/metadata-ingestion.md)
- [Governance & Classification](../concepts/governance-classification.md)
