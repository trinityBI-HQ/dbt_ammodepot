# API-Triggered Syncs

> **Purpose**: Orchestrate Airbyte syncs from data pipelines using Dagster, Prefect, or Airflow
> **MCP Validated**: 2026-02-19

## When to Use

- Integrate Airbyte syncs into broader data workflows
- Trigger syncs based on upstream pipeline completion
- Implement custom sync logic and retry strategies
- Monitor sync status and handle failures programmatically
- Build event-driven ELT pipelines

## Implementation

### Dagster Integration

```python
from dagster import op, job, OpExecutionContext, Failure
from dagster_airbyte import airbyte_resource, airbyte_sync_op
import requests
import time

# Method 1: Using dagster-airbyte package
airbyte_instance = airbyte_resource.configured({
    "host": "localhost",
    "port": "8000",
})

sync_customers = airbyte_sync_op.configured(
    {"connection_id": "connection-uuid"},
    name="sync_customers"
)

@job(resource_defs={"airbyte": airbyte_instance})
def airbyte_dagster_job():
    sync_customers()

# Method 2: Custom implementation with API
AIRBYTE_API = "https://api.airbyte.com/v1"
API_KEY = "your_api_key"

@op
def trigger_airbyte_sync(context: OpExecutionContext) -> str:
    """Trigger Airbyte connection sync via API."""
    response = requests.post(
        f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"},
        timeout=30
    )
    response.raise_for_status()

    job_id = response.json()["job"]["id"]
    context.log.info(f"Airbyte sync started: {job_id}")
    return job_id

@op
def wait_for_airbyte_sync(context: OpExecutionContext, job_id: str):
    """Poll sync status until completion."""
    max_wait_seconds = 3600  # 1 hour
    poll_interval = 30
    elapsed = 0

    while elapsed < max_wait_seconds:
        response = requests.get(
            f"{AIRBYTE_API}/jobs/{job_id}",
            headers={"Authorization": f"Bearer {API_KEY}"},
            timeout=30
        )
        response.raise_for_status()

        status = response.json()["job"]["status"]
        context.log.info(f"Job {job_id} status: {status}")

        if status == "succeeded":
            context.log.info("Sync completed successfully")
            return

        if status in ["failed", "cancelled"]:
            raise Failure(f"Airbyte sync failed with status: {status}")

        time.sleep(poll_interval)
        elapsed += poll_interval

    raise Failure(f"Airbyte sync timeout after {max_wait_seconds}s")

@op
def process_synced_data(context: OpExecutionContext):
    """Process data after Airbyte sync completes."""
    context.log.info("Processing synced data from Snowflake")
    # dbt run, custom transformations, etc.

@job
def elt_pipeline():
    """End-to-end ELT pipeline."""
    job_id = trigger_airbyte_sync()
    wait_for_airbyte_sync(job_id)
    process_synced_data()
```

### Prefect Integration

```python
from prefect import flow, task
import requests
import time

@task(retries=3, retry_delay_seconds=60)
def trigger_sync(connection_id: str) -> str:
    """Trigger Airbyte sync."""
    response = requests.post(
        f"{AIRBYTE_API}/connections/{connection_id}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    response.raise_for_status()
    return response.json()["job"]["id"]

@task(timeout_seconds=3600)
def wait_for_sync(job_id: str):
    """Wait for sync completion."""
    while True:
        response = requests.get(
            f"{AIRBYTE_API}/jobs/{job_id}",
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
        job = response.json()["job"]
        status = job["status"]

        if status == "succeeded":
            return job
        elif status in ["failed", "cancelled"]:
            raise Exception(f"Sync failed: {status}")

        time.sleep(30)

@flow(name="Airbyte ELT Pipeline")
def airbyte_elt_flow():
    """Orchestrate Airbyte sync."""
    job_id = trigger_sync("connection-uuid")
    job = wait_for_sync(job_id)
    print(f"Synced {job['recordsSynced']} records")
```

### Airflow Integration

```python
from airflow import DAG
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.providers.airbyte.sensors.airbyte import AirbyteJobSensor
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'airbyte_sync_pipeline',
    default_args=default_args,
    schedule_interval='0 */6 * * *',  # Every 6 hours
    start_date=datetime(2024, 1, 1),
    catchup=False,
) as dag:

    # Trigger sync
    trigger_sync = AirbyteTriggerSyncOperator(
        task_id='trigger_airbyte_sync',
        airbyte_conn_id='airbyte_default',
        connection_id='connection-uuid',
        asynchronous=True,
    )

    # Wait for completion
    wait_for_sync = AirbyteJobSensor(
        task_id='wait_for_sync',
        airbyte_conn_id='airbyte_default',
        airbyte_job_id=trigger_sync.output,
    )

    trigger_sync >> wait_for_sync
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `connection_id` | Required | UUID of Airbyte connection |
| `poll_interval` | 30 | Seconds between status checks |
| `timeout` | 3600 | Max seconds to wait for completion |
| `retries` | 3 | Number of retry attempts on failure |

## Error Handling

```python
@op
def trigger_with_retry(context: OpExecutionContext) -> str:
    """Trigger sync with exponential backoff."""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = requests.post(
                f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
                headers={"Authorization": f"Bearer {API_KEY}"},
                timeout=30
            )
            response.raise_for_status()
            return response.json()["job"]["id"]

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 429:  # Rate limit
                wait_time = 2 ** attempt * 10
                context.log.warning(f"Rate limited, waiting {wait_time}s")
                time.sleep(wait_time)
            elif e.response.status_code in [500, 502, 503]:
                context.log.warning(f"Server error, retry {attempt + 1}")
                time.sleep(5)
            else:
                raise

    raise Failure("Failed to trigger sync after retries")
```

## Example Usage

```python
# Dagster: Materialize asset that depends on Airbyte
from dagster import asset

@asset
def raw_customers():
    """Trigger Airbyte sync for customers."""
    job_id = trigger_airbyte_sync()
    wait_for_airbyte_sync(job_id)

@asset(deps=[raw_customers])
def transformed_customers():
    """Transform customers after sync."""
    # dbt run or custom SQL
    return "Transformation complete"

# Schedule
from dagster import ScheduleDefinition

daily_schedule = ScheduleDefinition(
    job=elt_pipeline,
    cron_schedule="0 2 * * *",  # 2 AM daily
)
```

## Monitoring and Observability

```python
@op
def log_sync_metrics(context: OpExecutionContext, job_id: str):
    """Log sync metrics for observability."""
    response = requests.get(
        f"{AIRBYTE_API}/jobs/{job_id}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    job = response.json()["job"]

    metrics = {
        "records_synced": job.get("recordsSynced", 0),
        "bytes_synced": job.get("bytesSynced", 0),
        "duration_seconds": (
            datetime.fromisoformat(job["endTime"]) -
            datetime.fromisoformat(job["startTime"])
        ).total_seconds(),
    }

    context.log_event(
        AssetMaterialization(
            asset_key="airbyte_sync",
            metadata={
                "records": MetadataValue.int(metrics["records_synced"]),
                "bytes": MetadataValue.int(metrics["bytes_synced"]),
                "duration": MetadataValue.float(metrics["duration_seconds"]),
            }
        )
    )
```

## Event-Driven Pattern

```python
# Trigger sync when file lands in S3
from dagster import sensor, RunRequest

@sensor(job=elt_pipeline)
def s3_file_sensor(context):
    """Trigger Airbyte sync when new S3 file detected."""
    new_files = check_s3_for_new_files()

    if new_files:
        return RunRequest(
            run_config={
                "ops": {
                    "trigger_airbyte_sync": {
                        "config": {"connection_id": "connection-uuid"}
                    }
                }
            }
        )
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Poll every second | Use 30s+ intervals |
| No timeout | Set reasonable timeout (1-2 hours) |
| Ignore errors | Implement retry logic |
| Block on sync | Use async/sensors |
| Hardcode connection IDs | Use config/variables |

## See Also

- [airbyte-api](../concepts/airbyte-api.md)
- [connections](../concepts/connections.md)
- [monitoring-observability](../patterns/monitoring-observability.md)
