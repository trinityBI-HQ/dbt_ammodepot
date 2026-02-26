# Data Lineage

> **Purpose**: Automated lineage, manual lineage, and column-level lineage tracking in OpenMetadata
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

OpenMetadata provides comprehensive lineage tracking at both table and column levels. Lineage can be automatically extracted from query logs (Snowflake, BigQuery, Redshift), pipeline tools (Airflow, dbt, Dagster), or manually defined through the UI and API. Lineage is visualized as a directed graph showing data flow from sources to downstream consumers.

## Lineage Sources

| Source | Method | Granularity |
|--------|--------|-------------|
| Query logs | Lineage workflow parses SQL | Table + column |
| dbt | manifest.json parsing | Table + column |
| Airflow | Lineage backend / operator | Table (via inlets/outlets) |
| Dagster | Asset dependency graph | Table |
| Spark | OpenLineage integration | Table + column |
| Manual | UI drag-and-drop or API | Table + column |

## Automated Lineage Workflow

The lineage workflow extracts dependencies by parsing SQL queries from database query logs:

```yaml
source:
  type: snowflake-lineage
  serviceName: snowflake_prod
  serviceConnection:
    config:
      type: Snowflake
      username: openmetadata_user
      password: ${SNOWFLAKE_PASSWORD}
      account: xy12345.us-east-1
  sourceConfig:
    config:
      type: DatabaseLineage
      queryLogDuration: 7  # days to look back
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

## Supported Lineage Databases

- Snowflake (via QUERY_HISTORY)
- BigQuery (via INFORMATION_SCHEMA.JOBS)
- Redshift (via STL_QUERY)
- PostgreSQL (via pg_stat_statements)
- MSSQL, ClickHouse, Databricks

## Column-Level Lineage

OpenMetadata traces individual column transformations:

```text
source_table.raw_email  -->  staging_table.email  -->  dim_customer.email_hash
                              (LOWER + TRIM)            (MD5 hash)
```

Column-level lineage is extracted from:
- SQL query parsing (CREATE TABLE AS SELECT, INSERT INTO SELECT)
- dbt manifest.json column-level dependencies
- Manual annotation through the UI

## Lineage API

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata

client = OpenMetadata(config)

# Get lineage for a table
lineage = client.get_lineage_by_name(
    entity=Table,
    fqn="snowflake_prod.analytics.public.dim_customer",
    up_depth=3,    # upstream hops
    down_depth=3   # downstream hops
)

# Add lineage edge programmatically
from metadata.generated.schema.api.lineage.addLineage import AddLineageRequest
from metadata.generated.schema.type.entityLineage import EntitiesEdge

edge = AddLineageRequest(
    edge=EntitiesEdge(
        fromEntity={"id": source_table_id, "type": "table"},
        toEntity={"id": target_table_id, "type": "table"}
    )
)
client.add_lineage(edge)
```

## Lineage Visualization

The OpenMetadata UI provides an interactive lineage graph:
- **Expand/collapse** upstream and downstream nodes
- **Filter** by entity type (tables, dashboards, pipelines)
- **Column-level** view to trace field transformations
- **Impact analysis** to see which downstream assets are affected by changes

## Cross-Tool Lineage

OpenMetadata can trace lineage across tool boundaries:

```text
PostgreSQL Table --> Airflow DAG --> Snowflake Table --> dbt Model --> Tableau Dashboard
```

This end-to-end visibility helps with impact analysis, root cause analysis, and compliance audits.

## Related

- [Architecture](../concepts/architecture.md)
- [Data Assets](../concepts/data-assets.md)
- [Integration Patterns](../patterns/integration-patterns.md)
