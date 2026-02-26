# Ingestion Patterns

> **Purpose**: Connector configuration, scheduling strategies, custom connectors, and ingestion best practices
> **MCP Validated**: 2026-02-19

## When to Use

- Connecting OpenMetadata to your data sources for metadata extraction
- Setting up scheduled ingestion workflows for continuous metadata freshness
- Building custom connectors for unsupported or internal data sources
- Configuring profiler and data quality ingestion alongside metadata

## Multi-Workflow Ingestion Pattern

Configure separate workflows for metadata, lineage, profiler, and quality:

```yaml
# 1. Metadata Ingestion (run first, daily)
source:
  type: snowflake
  serviceName: snowflake_prod
  serviceConnection:
    config:
      type: Snowflake
      username: ${SNOWFLAKE_USER}
      password: ${SNOWFLAKE_PASSWORD}
      account: xy12345.us-east-1
      warehouse: METADATA_WH
  sourceConfig:
    config:
      type: DatabaseMetadata
      markDeletedTables: true
      includeTags: true
      includeViews: true
      schemaFilterPattern:
        includes: ["analytics", "staging", "marts"]
        excludes: ["information_schema", "pg_catalog"]

# 2. Usage Ingestion (run daily, after metadata)
source:
  type: snowflake-usage
  serviceName: snowflake_prod
  sourceConfig:
    config:
      type: DatabaseUsage
      queryLogDuration: 7

# 3. Lineage Ingestion (run daily, after metadata)
source:
  type: snowflake-lineage
  serviceName: snowflake_prod
  sourceConfig:
    config:
      type: DatabaseLineage
      queryLogDuration: 7

# 4. Profiler (run on schedule, subset of tables)
source:
  type: snowflake
  serviceName: snowflake_prod
  sourceConfig:
    config:
      type: Profiler
      generateSampleData: true
      profileSample: 10  # percentage
      tableFilterPattern:
        includes: ["fact_.*", "dim_.*"]
```

## Airflow DAG Pattern

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

def run_metadata_ingestion():
    from metadata.workflow.metadata import MetadataWorkflow
    import yaml

    with open("/opt/airflow/configs/snowflake_metadata.yaml") as f:
        config = yaml.safe_load(f)

    workflow = MetadataWorkflow.create(config)
    workflow.execute()
    workflow.raise_from_status()
    workflow.print_status()
    workflow.stop()

def run_lineage_ingestion():
    from metadata.workflow.metadata import MetadataWorkflow
    import yaml

    with open("/opt/airflow/configs/snowflake_lineage.yaml") as f:
        config = yaml.safe_load(f)

    workflow = MetadataWorkflow.create(config)
    workflow.execute()
    workflow.raise_from_status()
    workflow.stop()

with DAG(
    "openmetadata_ingestion",
    schedule_interval="0 6 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
) as dag:

    metadata_task = PythonOperator(
        task_id="ingest_metadata",
        python_callable=run_metadata_ingestion,
    )

    lineage_task = PythonOperator(
        task_id="ingest_lineage",
        python_callable=run_lineage_ingestion,
    )

    metadata_task >> lineage_task
```

## Custom Connector Pattern

```python
from metadata.ingestion.api.steps import Source
from metadata.ingestion.api.models import Either
from metadata.generated.schema.entity.data.table import Table

class CustomAPISource(Source):
    """Custom connector for internal API metadata."""

    @classmethod
    def create(cls, config_dict, metadata, pipeline_name=None):
        return cls(config_dict, metadata)

    def prepare(self):
        """Initialize API client."""
        self.api_client = MyInternalAPIClient(
            base_url=self.service_connection.hostPort,
            token=self.service_connection.token,
        )

    def yield_data(self):
        """Extract metadata from custom source."""
        for dataset in self.api_client.list_datasets():
            table = CreateTableRequest(
                name=dataset["name"],
                databaseSchema=self.context.database_schema.fullyQualifiedName,
                columns=[
                    Column(name=col["name"], dataType=col["type"])
                    for col in dataset["columns"]
                ],
            )
            yield Either(right=table)

    def test_connection(self):
        """Validate connectivity."""
        self.api_client.health_check()
```

## Scheduling Best Practices

| Workflow | Frequency | Order | Notes |
|----------|-----------|-------|-------|
| Metadata | Daily (6 AM) | 1st | Foundation for all other workflows |
| Usage | Daily (7 AM) | 2nd | After metadata, needs tables to exist |
| Lineage | Daily (7:30 AM) | 3rd | After metadata, parses query logs |
| Profiler | Weekly or per-table | 4th | Resource-intensive, sample data |
| Data Quality | After profiler | 5th | Tests may depend on profiler stats |
| dbt | After dbt run | Any | Triggered by dbt job completion |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `markDeletedTables` | true | Mark tables as deleted if not found in source |
| `includeTags` | true | Import tags from source system |
| `includeViews` | true | Import views alongside tables |
| `profileSample` | 100 | Percentage of rows to sample for profiling |
| `queryLogDuration` | 1 | Days of query history to parse for lineage |
| `generateSampleData` | false | Store sample rows for preview |

## See Also

- [Metadata Ingestion](../concepts/metadata-ingestion.md)
- [Integration Patterns](../patterns/integration-patterns.md)
- [Deployment Patterns](../patterns/deployment-patterns.md)
