# Connectors

> **Purpose**: Pre-built integrations for extracting from sources and loading to destinations
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Airbyte connectors are modular components that handle data extraction from sources (databases, APIs, SaaS applications) and loading to destinations (warehouses, lakes, databases). With 350+ pre-built connectors, Airbyte covers most common data integration needs. Connectors implement the Airbyte Protocol, ensuring consistent behavior across all integrations.

## The Pattern

```python
# Connector configuration example (via API or Terraform)
{
  "sourceDefinitionId": "decd338e-5647-4c0b-adf4-da0e75f5a750",  # Postgres
  "connectionConfiguration": {
    "host": "database.example.com",
    "port": 5432,
    "database": "production",
    "username": "airbyte_user",
    "password": "${POSTGRES_PASSWORD}",
    "ssl": true,
    "replication_method": {
      "method": "CDC",
      "plugin": "pgoutput"
    }
  },
  "name": "Production Postgres"
}
```

## Quick Reference

| Connector Type | Count | Examples | Use Case |
|----------------|-------|----------|----------|
| Database Sources | 40+ | Postgres, MySQL, MongoDB, Oracle | Replicate database tables |
| API Sources | 100+ | Salesforce, HubSpot, Stripe, GitHub | Sync SaaS application data |
| File Sources | 20+ | S3, GCS, SFTP, Local files | Load files and CSVs |
| Data Warehouse Destinations | 10+ | Snowflake, BigQuery, Redshift, Databricks | Analytics warehouses |
| Database Destinations | 30+ | Postgres, MySQL, MongoDB | Operational databases |
| Lake Destinations | 5+ | S3, GCS, Azure Blob Storage | Data lakes (Parquet, JSON) |

## Source Connector Types

### Database Connectors

Support both full refresh and incremental sync using:
- **CDC (Change Data Capture)**: Real-time change tracking (Postgres, MySQL, SQL Server)
- **Cursor-based**: Use timestamp/ID column for incremental (all databases)

```yaml
# Incremental with cursor
cursor_field: updated_at
primary_key: [id]
```

### API Connectors

Handle pagination, rate limiting, and authentication:
- REST APIs with various pagination methods
- GraphQL APIs
- OAuth 2.0, API keys, JWT authentication

### File Connectors

Read structured/semi-structured files (CSV, JSON, Parquet, Avro) with wildcards, partitioned paths, and schema inference. As of v1.7, files and records can be synced in a single connection.

## Destination Connector Types

### Warehouse Destinations

Optimize for analytical workloads:
- Columnar storage formats
- Automatic schema evolution
- Typing and deduping for SCD Type 2

### Lake Destinations

Raw data storage with flexibility:
- Parquet format for efficiency
- Partitioning by date or custom keys
- No normalization overhead

## Connector Versioning

Airbyte uses semantic versioning (e.g., `0.3.12`):
- **Major version**: Breaking changes
- **Minor version**: New features, backward compatible
- **Patch version**: Bug fixes

```bash
# Pin connector version in Terraform
version = "0.3.12"
```

## Connector Development (2.0)

### Stream Templates (v1.7+)

Low-code CDK feature for generating multiple streams from a single template definition. Reduces boilerplate for APIs with many similar endpoints.

### AI-Configured Connections (Dec 2025)

AI auto-configures connections from natural language descriptions, selecting connectors, mapping fields, and setting sync modes.

## Connector Certification Levels

| Level | Description | SLA |
|-------|-------------|-----|
| **Certified** | Production-ready, Airbyte maintained | High |
| **Community** | Community contributions | Best effort |
| **Custom** | Built with Python CDK | Self-maintained |

## Common Mistakes

### Wrong

```python
# Anti-pattern: Using generic credentials
{
  "username": "admin",
  "password": "password123",  # Hardcoded password
  "ssl": false  # Insecure connection
}
```

### Correct

```python
# Correct: Secure configuration
{
  "username": "airbyte_readonly",  # Least privilege
  "password": "${SECRET_MANAGER_PASSWORD}",  # Secret reference
  "ssl": true,
  "ssl_mode": "require"
}
```

## Connector Discovery

When a connector connects to a source, it performs **schema discovery**, returning a catalog of available streams with their schemas, supported sync modes, and default cursor fields. See [catalog-schema](../concepts/catalog-schema.md) for details.

## Related

- [sync-modes](../concepts/sync-modes.md)
- [connections](../concepts/connections.md)
- [catalog-schema](../concepts/catalog-schema.md)
- [custom-python-connector](../patterns/custom-python-connector.md)
