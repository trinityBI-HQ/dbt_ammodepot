# Integration Patterns

> **Purpose**: Integrating OpenMetadata with Airflow, dbt, Dagster, Great Expectations, and other tools
> **MCP Validated**: 2026-02-19

## When to Use

- Connecting OpenMetadata to your existing data stack for automated lineage
- Ingesting dbt metadata (models, tests, descriptions) into OpenMetadata
- Setting up Airflow lineage tracking through the OpenMetadata backend
- Extracting Dagster asset metadata and lineage
- Importing Great Expectations test results

## Airflow Integration

### Lineage Backend (Recommended)

Install the OpenMetadata Airflow lineage backend to automatically capture DAG lineage:

```bash
pip install "openmetadata-ingestion[airflow]"
```

```ini
# airflow.cfg
[lineage]
backend = airflow_provider_openmetadata.lineage.backend.OpenMetadataLineageBackend
airflow_service_name = airflow_prod
openmetadata_api_endpoint = http://openmetadata:8585/api
jwt_token = <your-jwt-token>
```

### Lineage via Inlets/Outlets

```python
from airflow.decorators import task
from airflow.lineage.entities import Table as LineageTable

inlet_table = LineageTable(
    database="snowflake_prod",
    cluster="analytics",
    schema="raw",
    name="raw_orders",
)
outlet_table = LineageTable(
    database="snowflake_prod",
    cluster="analytics",
    schema="staging",
    name="stg_orders",
)

@task(inlets=[inlet_table], outlets=[outlet_table])
def transform_orders():
    """Transform raw orders to staging."""
    # Transformation logic here
    pass
```

### Airflow Metadata Connector

```yaml
source:
  type: airflow
  serviceName: airflow_prod
  serviceConnection:
    config:
      type: Airflow
      hostPort: http://airflow:8080
      connection:
        type: BackendConnection
  sourceConfig:
    config:
      type: PipelineMetadata
```

## dbt Integration

### dbt Metadata Ingestion

OpenMetadata ingests dbt artifacts to enrich table metadata with descriptions, tags, owners, and lineage:

```yaml
source:
  type: dbt
  serviceName: snowflake_prod
  sourceConfig:
    config:
      type: DBT
      dbtConfigSource:
        dbtCatalogFilePath: /path/to/catalog.json
        dbtManifestFilePath: /path/to/manifest.json
        dbtRunResultsFilePath: /path/to/run_results.json
      dbtUpdateDescriptions: true
      includeTags: true
      dbtClassificationName: dbtTags
```

### dbt Cloud Connector

```yaml
source:
  type: dbtcloud
  serviceName: dbt_cloud_prod
  serviceConnection:
    config:
      type: DBTCloud
      host: https://cloud.getdbt.com
      discoveryAPI: https://metadata.cloud.getdbt.com/graphql
      accountId: "12345"
      jobId: "67890"
      token: ${DBT_CLOUD_TOKEN}
```

### What dbt Ingestion Captures

| Artifact | OpenMetadata Entity | Details |
|----------|-------------------|---------|
| manifest.json | Table descriptions | Model descriptions, column descriptions |
| manifest.json | Lineage | Model dependencies (ref, source) |
| manifest.json | Tags | dbt tags mapped to classifications |
| run_results.json | Test results | dbt test pass/fail mapped to quality |
| catalog.json | Column metadata | Data types, statistics |

## Dagster Integration

```yaml
source:
  type: dagster
  serviceName: dagster_prod
  serviceConnection:
    config:
      type: Dagster
      host: http://dagster-webserver:3000
      token: ${DAGSTER_TOKEN}
  sourceConfig:
    config:
      type: PipelineMetadata
```

Dagster asset dependencies are automatically mapped to lineage edges in OpenMetadata. When a Dagster asset depends on another asset, OpenMetadata creates lineage between the corresponding tables.

## Great Expectations Integration

Import Great Expectations test results into OpenMetadata:

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata
from metadata.generated.schema.tests.testCase import TestCase

client = OpenMetadata(config)

# After running GE checkpoint, push results to OpenMetadata
import great_expectations as ge

context = ge.get_context()
result = context.run_checkpoint(checkpoint_name="orders_checkpoint")

for validation in result.list_validation_results():
    for test_result in validation.results:
        # Map GE expectations to OpenMetadata test cases
        client.add_test_case_results(
            test_case_fqn="snowflake_prod.analytics.public.orders.order_id_not_null",
            test_case_results=TestCaseResult(
                timestamp=int(datetime.now().timestamp()),
                testCaseStatus="Success" if test_result.success else "Failed",
                result=str(test_result.result),
            ),
        )
```

## Integration Matrix

| Tool | Metadata | Lineage | Quality | Method |
|------|----------|---------|---------|--------|
| Airflow | Yes | Yes | No | Connector + Lineage Backend |
| dbt | Yes | Yes | Yes | Artifact ingestion |
| Dagster | Yes | Yes | No | Connector |
| Great Expectations | No | No | Yes | API / SDK |
| Spark | No | Yes | No | OpenLineage |
| Kafka | Yes | No | No | Connector |
| Tableau/Power BI | Yes | Yes | No | Connector |
| Snowflake | Yes | Yes | Yes | Connector + Profiler |

## See Also

- [Metadata Ingestion](../concepts/metadata-ingestion.md)
- [Data Lineage](../concepts/data-lineage.md)
- [Ingestion Patterns](../patterns/ingestion-patterns.md)
- [Dagster KB](../../../orchestration/dagster/)
- [dbt Core KB](../../../transformation/dbt-core/)
- [Great Expectations KB](../../../data-quality/great-expectations/)
