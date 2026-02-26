# Airbyte API

> **Purpose**: REST API for programmatic control of sources, destinations, and connections
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Airbyte API provides programmatic access to all platform functionality, enabling infrastructure as code, automated testing, and orchestration integrations. The API is RESTful, uses JSON payloads, and supports creating/updating/deleting sources, destinations, connections, and triggering syncs. Both Cloud and OSS expose the same API surface with slight authentication differences.

## The Pattern

```python
import requests

BASE_URL = "https://api.airbyte.com/v1"
API_KEY = "your_api_key"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Create a source
response = requests.post(
    f"{BASE_URL}/sources",
    headers=headers,
    json={
        "name": "Production Postgres",
        "sourceDefinitionId": "decd338e-5647-4c0b-adf4-da0e75f5a750",
        "workspaceId": "your-workspace-id",
        "connectionConfiguration": {
            "host": "db.example.com",
            "port": 5432,
            "database": "prod",
            "username": "airbyte",
            "password": "secret"
        }
    }
)

source_id = response.json()["sourceId"]
```

## Quick Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/workspaces` | GET | List workspaces |
| `/source_definitions` | GET | List available source connectors |
| `/destination_definitions` | GET | List available destination connectors |
| `/sources` | POST | Create source |
| `/sources/{id}` | PUT | Update source |
| `/destinations` | POST | Create destination |
| `/connections` | POST | Create connection |
| `/connections/{id}/sync` | POST | Trigger sync |
| `/jobs/{id}` | GET | Get job status |

## Authentication

### Cloud API

```python
# API key from Airbyte Cloud settings
headers = {
    "Authorization": f"Bearer {AIRBYTE_CLOUD_API_KEY}"
}
```

### OSS API

```python
# Basic auth (default: no authentication)
headers = {
    "Authorization": "Basic YWlyYnl0ZTpwYXNzd29yZA=="  # Optional
}
```

## Core Operations

### 1. List Connectors

```python
# Get available source connectors
response = requests.get(
    f"{BASE_URL}/source_definitions",
    headers=headers
)

for connector in response.json()["sourceDefinitions"]:
    print(f"{connector['name']}: {connector['sourceDefinitionId']}")

# Output:
# Postgres: decd338e-5647-4c0b-adf4-da0e75f5a750
# MySQL: 435bb9a5-7887-4809-aa58-28c27df0d7ad
# Snowflake: b21c0607-4533-4a54-96d2-cd04a73b1cf4
```

### 2. Create Source

```python
source_payload = {
    "name": "Production MySQL",
    "sourceDefinitionId": "435bb9a5-7887-4809-aa58-28c27df0d7ad",
    "workspaceId": "workspace-uuid",
    "connectionConfiguration": {
        "host": "mysql.example.com",
        "port": 3306,
        "database": "production",
        "username": "readonly_user",
        "password": "${MYSQL_PASSWORD}",
        "replication_method": "STANDARD"
    }
}

response = requests.post(
    f"{BASE_URL}/sources",
    headers=headers,
    json=source_payload
)
```

### 3. Create Destination

```python
destination_payload = {
    "name": "Snowflake Data Warehouse",
    "destinationDefinitionId": "424892c4-daac-4491-b35d-c6688ba547ba",
    "workspaceId": "workspace-uuid",
    "connectionConfiguration": {
        "host": "account.snowflakecomputing.com",
        "role": "AIRBYTE_ROLE",
        "warehouse": "AIRBYTE_WAREHOUSE",
        "database": "ANALYTICS",
        "schema": "RAW",
        "username": "AIRBYTE_USER",
        "credentials": {
            "password": "${SNOWFLAKE_PASSWORD}"
        }
    }
}

response = requests.post(
    f"{BASE_URL}/destinations",
    headers=headers,
    json=destination_payload
)
```

### 4. Create Connection

```python
connection_payload = {
    "name": "MySQL → Snowflake",
    "sourceId": "source-uuid",
    "destinationId": "destination-uuid",
    "schedule": {
        "scheduleType": "cron",
        "cronExpression": "0 */6 * * *"  # Every 6 hours
    },
    "namespaceDefinition": "destination",
    "namespaceFormat": "raw",
    "prefix": "mysql_",
    "status": "active",
    "syncCatalog": {
        "streams": [
            {
                "stream": {
                    "name": "users",
                    "jsonSchema": {...},
                    "supportedSyncModes": ["full_refresh", "incremental"]
                },
                "config": {
                    "syncMode": "incremental",
                    "destinationSyncMode": "append_deduped",
                    "cursorField": ["updated_at"],
                    "primaryKey": [["id"]],
                    "selected": True
                }
            }
        ]
    }
}

response = requests.post(
    f"{BASE_URL}/connections",
    headers=headers,
    json=connection_payload
)
```

### 5. Trigger Sync

```python
# Manual sync trigger
response = requests.post(
    f"{BASE_URL}/connections/{connection_id}/sync",
    headers=headers
)

job_id = response.json()["job"]["id"]
print(f"Sync job started: {job_id}")
```

### 6. Monitor Job

```python
import time

def wait_for_job(job_id):
    """Poll job status until completion."""
    while True:
        response = requests.get(
            f"{BASE_URL}/jobs/{job_id}",
            headers=headers
        )
        job = response.json()["job"]
        status = job["status"]

        if status in ["succeeded", "failed", "cancelled"]:
            return status

        print(f"Job {job_id} status: {status}")
        time.sleep(30)

status = wait_for_job(job_id)
print(f"Final status: {status}")
```

## Orchestration Integration

### Dagster

```python
from dagster import op, job, OpExecutionContext
import requests

@op
def trigger_airbyte_sync(context: OpExecutionContext):
    """Trigger Airbyte connection sync."""
    response = requests.post(
        f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    job_id = response.json()["job"]["id"]
    context.log.info(f"Airbyte sync started: {job_id}")
    return job_id

@op
def wait_for_sync(context: OpExecutionContext, job_id: str):
    """Wait for sync completion."""
    while True:
        response = requests.get(
            f"{AIRBYTE_API}/jobs/{job_id}",
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
        status = response.json()["job"]["status"]

        if status == "succeeded":
            context.log.info("Sync completed successfully")
            return
        elif status in ["failed", "cancelled"]:
            raise Exception(f"Sync failed with status: {status}")

        time.sleep(30)

@job
def airbyte_pipeline():
    job_id = trigger_airbyte_sync()
    wait_for_sync(job_id)
```

### Prefect

```python
from prefect import flow, task
import requests

@task
def trigger_sync():
    response = requests.post(
        f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
        headers={"Authorization": f"Bearer {API_KEY}"}
    )
    return response.json()["job"]["id"]

@flow
def airbyte_flow():
    job_id = trigger_sync()
    # Wait logic here
```

## Common Mistakes

### Wrong

```python
# Anti-pattern: Polling too frequently
while True:
    status = check_job_status(job_id)
    if status == "succeeded":
        break
    time.sleep(1)  # Poll every second (rate limit!)
```

### Correct

```python
# Correct: Reasonable polling interval
while True:
    status = check_job_status(job_id)
    if status in ["succeeded", "failed", "cancelled"]:
        break
    time.sleep(30)  # Poll every 30 seconds
```

## Error Handling

```python
try:
    response = requests.post(
        f"{BASE_URL}/connections/{connection_id}/sync",
        headers=headers,
        timeout=30
    )
    response.raise_for_status()
    job_id = response.json()["job"]["id"]
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 404:
        print(f"Connection {connection_id} not found")
    elif e.response.status_code == 429:
        print("Rate limit exceeded, retry later")
    else:
        print(f"API error: {e.response.text}")
except requests.exceptions.Timeout:
    print("API request timed out")
```

## Related

- [connections](../concepts/connections.md)
- [terraform-orchestration](../patterns/terraform-orchestration.md)
- [api-triggered-syncs](../patterns/api-triggered-syncs.md)
