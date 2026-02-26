# Cloud Integrations Pattern

> **Purpose**: Connecting Dagster to BigQuery, Snowflake, S3, GCS, and Spark
> **MCP Validated**: 2026-02-19

## When to Use

- Reading/writing to cloud data warehouses
- Storing asset outputs in cloud storage
- BI tools as first-class assets in lineage graph (v1.9)
- Migrating incrementally from Airflow (Airlift toolkit)
- Building multi-cloud data pipelines

## Implementation

### Snowflake Integration

```python
import dagster as dg
from dagster_snowflake import SnowflakeResource
from dagster_snowflake_pandas import SnowflakePandasIOManager
import pandas as pd

# Resource for direct queries
snowflake_resource = SnowflakeResource(
    account=dg.EnvVar("SNOWFLAKE_ACCOUNT"),
    user=dg.EnvVar("SNOWFLAKE_USER"),
    password=dg.EnvVar("SNOWFLAKE_PASSWORD"),
    database="ANALYTICS",
    warehouse="COMPUTE_WH",
    schema="PUBLIC",
)

# IO Manager for automatic table storage
snowflake_io = SnowflakePandasIOManager(
    account=dg.EnvVar("SNOWFLAKE_ACCOUNT"),
    user=dg.EnvVar("SNOWFLAKE_USER"),
    password=dg.EnvVar("SNOWFLAKE_PASSWORD"),
    database="ANALYTICS",
    warehouse="COMPUTE_WH",
    schema="DAGSTER",
)

@dg.asset(io_manager_key="snowflake_io")
def customer_metrics() -> pd.DataFrame:
    """Automatically written to Snowflake."""
    return pd.DataFrame({"metric": ["revenue"], "value": [1000000]})

@dg.asset
def custom_query(snowflake: SnowflakeResource) -> pd.DataFrame:
    """Use resource for custom queries."""
    with snowflake.get_connection() as conn:
        return pd.read_sql("SELECT * FROM raw.customers", conn)

defs = dg.Definitions(
    assets=[customer_metrics, custom_query],
    resources={
        "snowflake": snowflake_resource,
        "snowflake_io": snowflake_io,
    },
)
```

### BigQuery Integration

```python
from dagster_gcp import BigQueryResource
from dagster_gcp_pandas import BigQueryPandasIOManager

bigquery_resource = BigQueryResource(
    project=dg.EnvVar("GCP_PROJECT"),
    location="US",
)

bigquery_io = BigQueryPandasIOManager(
    project=dg.EnvVar("GCP_PROJECT"),
    dataset="dagster_assets",
    location="US",
)

@dg.asset(io_manager_key="bigquery_io")
def bq_metrics() -> pd.DataFrame:
    """Written to BigQuery table."""
    return pd.DataFrame({"date": ["2024-01-01"], "visits": [10000]})

@dg.asset
def bq_query(bigquery: BigQueryResource) -> pd.DataFrame:
    """Custom BigQuery query."""
    return bigquery.query("SELECT * FROM `project.dataset.table`")
```

### S3 Integration

```python
from dagster_aws.s3 import S3Resource, S3PickleIOManager

s3_resource = S3Resource(
    region_name="us-west-2",
    aws_access_key_id=dg.EnvVar("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=dg.EnvVar("AWS_SECRET_ACCESS_KEY"),
)

s3_io = S3PickleIOManager(
    s3_resource=s3_resource,
    s3_bucket="my-dagster-bucket",
    s3_prefix="assets",
)

@dg.asset
def upload_to_s3(s3: S3Resource) -> str:
    """Direct S3 upload."""
    s3.get_client().put_object(
        Bucket="my-bucket",
        Key="data/output.json",
        Body=b'{"result": "success"}',
    )
    return "s3://my-bucket/data/output.json"
```

### GCS Integration

```python
from dagster_gcp import GCSResource, GCSPickleIOManager

gcs_io = GCSPickleIOManager(gcs_bucket="my-dagster-bucket", gcs_prefix="assets")
```

## Configuration

| Service | IO Manager | Resource |
|---------|------------|----------|
| Snowflake | `SnowflakePandasIOManager` | `SnowflakeResource` |
| BigQuery | `BigQueryPandasIOManager` | `BigQueryResource` |
| S3 | `S3PickleIOManager` | `S3Resource` |
| GCS | `GCSPickleIOManager` | `GCSResource` |

## BI Integrations (v1.9)

First-class Tableau, Power BI, Looker, and Sigma integrations. BI assets appear in the asset graph with upstream lineage.

```python
from dagster_tableau import TableauCloudWorkspace, load_tableau_asset_specs
import dagster as dg

tableau_workspace = TableauCloudWorkspace(
    connected_app_client_id=dg.EnvVar("TABLEAU_CLIENT_ID"),
    connected_app_secret_id=dg.EnvVar("TABLEAU_SECRET_ID"),
    connected_app_secret_value=dg.EnvVar("TABLEAU_SECRET_VALUE"),
    username=dg.EnvVar("TABLEAU_USERNAME"),
    site_name=dg.EnvVar("TABLEAU_SITE_NAME"),
    pod_name=dg.EnvVar("TABLEAU_POD_NAME"),
)
tableau_specs = load_tableau_asset_specs(tableau_workspace)

defs = dg.Definitions(
    assets=[*tableau_specs, *other_assets],
    resources={"tableau": tableau_workspace},
)
```

Packages: `dagster-tableau`, `dagster-powerbi`, `dagster-looker`, `dagster-sigma`.

## Airlift -- Airflow Migration (v1.9)

Incremental migration toolkit. Run Airflow tasks from Dagster without rewriting DAGs.

```python
# pip install dagster-airlift
from dagster_airlift.core import assets_with_task_mappings, build_defs_from_airflow_instance

defs = build_defs_from_airflow_instance(
    airflow_instance=AirflowInstance(
        auth_backend=BasicAuthBackend("admin", dg.EnvVar("AIRFLOW_PASSWORD")),
        name="production",
    ),
    defs=assets_with_task_mappings(
        dag_id="my_dag",
        task_mappings={"extract_task": [AssetSpec("raw_data")]},
    ),
)
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode credentials | Use `EnvVar` for all secrets |
| Mix IO managers randomly | Standardize per data tier |
| Skip connection pooling | Use resource connections |
| Ignore temp bucket for Spark | Configure `temporary_gcs_bucket` |

## See Also

- [io-managers](../concepts/io-managers.md)
- [resources](../concepts/resources.md)
- [dbt-integration](../patterns/dbt-integration.md)
