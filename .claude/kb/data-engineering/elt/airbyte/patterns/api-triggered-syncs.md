# API-Triggered Syncs

> **Purpose**: Orchestrate Airbyte syncs from data pipelines using Dagster, Prefect, or Airflow
> **MCP Validated**: 2026-02-19

## When to Use

- Integrate Airbyte syncs into broader data workflows
- Trigger syncs based on upstream pipeline completion
- Monitor sync status and handle failures programmatically
- Build event-driven ELT pipelines

## Implementation

### Dagster Integration

```python
from dagster import op, job, Failure
from dagster_airbyte import airbyte_resource, airbyte_sync_op
import requests, time

# Method 1: dagster-airbyte package
airbyte_instance = airbyte_resource.configured({"host": "localhost", "port": "8000"})
sync_customers = airbyte_sync_op.configured(
    {"connection_id": "connection-uuid"}, name="sync_customers"
)

@job(resource_defs={"airbyte": airbyte_instance})
def airbyte_dagster_job():
    sync_customers()

# Method 2: Custom API implementation
AIRBYTE_API = "https://api.airbyte.com/v1"

@op
def trigger_airbyte_sync(context) -> str:
    response = requests.post(
        f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"}, timeout=30
    )
    response.raise_for_status()
    job_id = response.json()["job"]["id"]
    context.log.info(f"Sync started: {job_id}")
    return job_id

@op
def wait_for_airbyte_sync(context, job_id: str):
    elapsed = 0
    while elapsed < 3600:
        response = requests.get(
            f"{AIRBYTE_API}/jobs/{job_id}",
            headers={"Authorization": f"Bearer {API_KEY}"}, timeout=30
        )
        status = response.json()["job"]["status"]
        if status == "succeeded":
            return
        if status in ["failed", "cancelled"]:
            raise Failure(f"Sync failed: {status}")
        time.sleep(30)
        elapsed += 30
    raise Failure("Sync timeout")

@job
def elt_pipeline():
    job_id = trigger_airbyte_sync()
    wait_for_airbyte_sync(job_id)
```

### Airflow Integration

```python
from airflow import DAG
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.providers.airbyte.sensors.airbyte import AirbyteJobSensor
from datetime import datetime, timedelta

with DAG(
    'airbyte_sync_pipeline',
    default_args={'retries': 2, 'retry_delay': timedelta(minutes=5)},
    schedule_interval='0 */6 * * *',
    start_date=datetime(2024, 1, 1),
    catchup=False,
) as dag:
    trigger = AirbyteTriggerSyncOperator(
        task_id='trigger_sync', airbyte_conn_id='airbyte_default',
        connection_id='connection-uuid', asynchronous=True,
    )
    wait = AirbyteJobSensor(
        task_id='wait_for_sync', airbyte_conn_id='airbyte_default',
        airbyte_job_id=trigger.output,
    )
    trigger >> wait
```

### Prefect Integration

```python
from prefect import flow, task
import requests, time

@task(retries=3, retry_delay_seconds=60)
def trigger_sync(connection_id: str) -> str:
    response = requests.post(
        f"{AIRBYTE_API}/connections/{connection_id}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    response.raise_for_status()
    return response.json()["job"]["id"]

@task(timeout_seconds=3600)
def wait_for_sync(job_id: str):
    while True:
        status = requests.get(
            f"{AIRBYTE_API}/jobs/{job_id}",
            headers={"Authorization": f"Bearer {API_KEY}"}
        ).json()["job"]["status"]
        if status == "succeeded": return
        if status in ["failed", "cancelled"]: raise Exception(f"Sync failed: {status}")
        time.sleep(30)

@flow(name="Airbyte ELT Pipeline")
def airbyte_elt_flow():
    job_id = trigger_sync("connection-uuid")
    wait_for_sync(job_id)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `connection_id` | Required | UUID of Airbyte connection |
| `poll_interval` | 30s | Seconds between status checks |
| `timeout` | 3600s | Max wait for completion |
| `retries` | 3 | Retry attempts on failure |

## Error Handling

Handle rate limits (429) with exponential backoff, server errors (5xx) with retries, and set reasonable timeouts. Always check for `failed` and `cancelled` statuses.

## Event-Driven Pattern

```python
from dagster import sensor, RunRequest

@sensor(job=elt_pipeline)
def s3_file_sensor(context):
    new_files = check_s3_for_new_files()
    if new_files:
        return RunRequest(run_config={"ops": {
            "trigger_airbyte_sync": {"config": {"connection_id": "uuid"}}
        }})
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Poll every second | Use 30s+ intervals |
| No timeout | Set 1-2 hour timeout |
| Ignore errors | Implement retry with backoff |
| Hardcode connection IDs | Use config/variables |

## See Also

- [airbyte-api](../concepts/airbyte-api.md)
- [connections](../concepts/connections.md)
- [monitoring-observability](../patterns/monitoring-observability.md)
