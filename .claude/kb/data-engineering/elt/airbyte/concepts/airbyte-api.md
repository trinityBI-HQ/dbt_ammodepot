# Airbyte API

> **Purpose**: REST API for programmatic control of sources, destinations, and connections
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Airbyte API provides programmatic access to all platform functionality: creating sources, destinations, connections, and triggering syncs. RESTful with JSON payloads. Both Cloud and OSS expose the same API surface.

## Quick Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/sources` | POST | Create source |
| `/sources/{id}` | PUT | Update source |
| `/destinations` | POST | Create destination |
| `/connections` | POST | Create connection |
| `/connections/{id}/sync` | POST | Trigger sync |
| `/jobs/{id}` | GET | Get job status |

## Authentication

```python
# Cloud: API key from settings
headers = {"Authorization": f"Bearer {AIRBYTE_CLOUD_API_KEY}"}

# OSS: Basic auth (optional)
headers = {"Authorization": "Basic YWlyYnl0ZTpwYXNzd29yZA=="}
```

## Core Operations

```python
import requests

BASE_URL = "https://api.airbyte.com/v1"
headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

# Create source
response = requests.post(f"{BASE_URL}/sources", headers=headers, json={
    "name": "Production Postgres",
    "sourceDefinitionId": "decd338e-5647-4c0b-adf4-da0e75f5a750",
    "workspaceId": "your-workspace-id",
    "connectionConfiguration": {
        "host": "db.example.com", "port": 5432,
        "database": "prod", "username": "airbyte", "password": "secret"
    }
})

# Create connection with incremental sync
requests.post(f"{BASE_URL}/connections", headers=headers, json={
    "name": "Postgres -> Snowflake",
    "sourceId": "source-uuid",
    "destinationId": "dest-uuid",
    "schedule": {"scheduleType": "cron", "cronExpression": "0 */6 * * *"},
    "syncCatalog": {"streams": [{
        "stream": {"name": "users", "supportedSyncModes": ["incremental"]},
        "config": {"syncMode": "incremental", "destinationSyncMode": "append_deduped",
                   "cursorField": ["updated_at"], "primaryKey": [["id"]], "selected": True}
    }]}
})

# Trigger sync and poll for completion
response = requests.post(f"{BASE_URL}/connections/{conn_id}/sync", headers=headers)
job_id = response.json()["job"]["id"]

while True:
    status = requests.get(f"{BASE_URL}/jobs/{job_id}", headers=headers).json()["job"]["status"]
    if status in ["succeeded", "failed", "cancelled"]:
        break
    time.sleep(30)  # Poll every 30s (not 1s!)
```

## Orchestration (Dagster)

```python
from dagster import op, job

@op
def trigger_airbyte_sync(context):
    response = requests.post(f"{AIRBYTE_API}/connections/{CONNECTION_ID}/sync",
                             headers={"Authorization": f"Bearer {API_KEY}"})
    return response.json()["job"]["id"]

@op
def wait_for_sync(context, job_id: str):
    while True:
        status = requests.get(f"{AIRBYTE_API}/jobs/{job_id}",
                              headers={"Authorization": f"Bearer {API_KEY}"}).json()["job"]["status"]
        if status == "succeeded": return
        elif status in ["failed", "cancelled"]: raise Exception(f"Sync {status}")
        time.sleep(30)

@job
def airbyte_pipeline():
    wait_for_sync(trigger_airbyte_sync())
```

## Error Handling

```python
try:
    response = requests.post(f"{BASE_URL}/connections/{conn_id}/sync", headers=headers, timeout=30)
    response.raise_for_status()
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 404: print("Connection not found")
    elif e.response.status_code == 429: print("Rate limit exceeded")
except requests.exceptions.Timeout:
    print("Request timed out")
```

## Related

- [connections](../concepts/connections.md)
- [terraform-orchestration](../patterns/terraform-orchestration.md)
- [api-triggered-syncs](../patterns/api-triggered-syncs.md)
