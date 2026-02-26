# Metadata Ingestion

> **Purpose**: Connectors, ingestion framework, workflow types, and scheduling in OpenMetadata
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The OpenMetadata Ingestion Framework is a Python-based system for extracting metadata from external sources through 80+ connectors. It supports six workflow types (metadata, usage, lineage, profiler, data quality, dbt) and can be orchestrated via Airflow, Dagster, or run standalone.

## Workflow Types

| Workflow | Purpose | Data Extracted |
|----------|---------|---------------|
| Metadata | Structural metadata | Tables, schemas, columns, constraints |
| Usage | Query execution patterns | Popular tables, frequent queries |
| Lineage | Data dependencies | Table/column-level lineage |
| Profiler | Data statistics | Row counts, null %, distributions |
| Data Quality | Test execution | Test pass/fail, incidents |
| dbt | dbt artifacts | Models, tests, descriptions, lineage |

## Connector Configuration (YAML)

```yaml
source:
  type: snowflake
  serviceName: snowflake_prod
  serviceConnection:
    config:
      type: Snowflake
      username: openmetadata_user
      password: ${SNOWFLAKE_PASSWORD}
      account: xy12345.us-east-1
      warehouse: COMPUTE_WH
      database: ANALYTICS
  sourceConfig:
    config:
      type: DatabaseMetadata
      schemaFilterPattern:
        includes:
          - "public"
          - "staging"
sink:
  type: metadata-rest
  config: {}
workflowConfig:
  openMetadataServerConfig:
    hostPort: http://localhost:8585/api
    authProvider: openmetadata
    securityConfig:
      jwtToken: ${OM_JWT_TOKEN}
```

## Running Ingestion

```bash
# Install connector package
pip install "openmetadata-ingestion[snowflake]"

# Run via CLI
metadata ingest -c snowflake_config.yaml

# Run profiler
metadata profile -c snowflake_profiler.yaml

# Run data quality tests
metadata test -c snowflake_tests.yaml
```

## Python SDK Ingestion

```python
from metadata.workflow.metadata import MetadataWorkflow

config = {
    "source": {
        "type": "snowflake",
        "serviceName": "snowflake_prod",
        "serviceConnection": {
            "config": {
                "type": "Snowflake",
                "username": "user",
                "password": "pass",
                "account": "xy12345.us-east-1"
            }
        },
        "sourceConfig": {"config": {"type": "DatabaseMetadata"}}
    },
    "sink": {"type": "metadata-rest", "config": {}},
    "workflowConfig": {
        "openMetadataServerConfig": {
            "hostPort": "http://localhost:8585/api",
            "authProvider": "openmetadata",
            "securityConfig": {"jwtToken": "<token>"}
        }
    }
}

workflow = MetadataWorkflow.create(config)
workflow.execute()
workflow.raise_from_status()
workflow.print_status()
workflow.stop()
```

## Filter Patterns

Control which schemas, tables, or databases to include/exclude:

| Filter | Purpose | Example |
|--------|---------|---------|
| `databaseFilterPattern` | Include/exclude databases | `includes: ["analytics"]` |
| `schemaFilterPattern` | Include/exclude schemas | `excludes: ["information_schema"]` |
| `tableFilterPattern` | Include/exclude tables | `includes: ["dim_.*", "fact_.*"]` |

## Scheduling

Ingestion workflows can be scheduled via:

- **OpenMetadata UI**: Built-in cron scheduler for each connector
- **Airflow**: Deploy as DAGs with `metadata_ingestion_workflow()` callable
- **Dagster**: Asset-based ingestion scheduling
- **External cron**: CLI invocation on schedule

## Related

- [Architecture](../concepts/architecture.md)
- [Data Assets](../concepts/data-assets.md)
- [Ingestion Patterns](../patterns/ingestion-patterns.md)
- [Integration Patterns](../patterns/integration-patterns.md)
