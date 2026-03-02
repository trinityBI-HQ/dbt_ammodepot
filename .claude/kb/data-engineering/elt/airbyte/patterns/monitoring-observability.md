# Monitoring and Observability

> **Purpose**: Monitor Airbyte sync health, performance, and data quality
> **MCP Validated**: 2026-02-19

## When to Use

- Production Airbyte deployments requiring uptime SLAs
- Need alerting on sync failures or data quality issues
- Track sync performance and optimize costs
- Detect schema drift or data anomalies

## Implementation

### Python Monitoring Script

```python
import requests, time
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import List, Optional

@dataclass
class SyncMetrics:
    connection_id: str
    connection_name: str
    status: str
    records_synced: int
    bytes_synced: int
    duration_seconds: float
    start_time: datetime

class AirbyteMonitor:
    def __init__(self, api_url: str, api_key: str):
        self.api_url = api_url
        self.headers = {"Authorization": f"Bearer {api_key}"}

    def get_connections(self) -> List[dict]:
        response = requests.get(f"{self.api_url}/connections", headers=self.headers)
        response.raise_for_status()
        return response.json()["connections"]

    def get_latest_sync(self, connection_id: str) -> Optional[SyncMetrics]:
        response = requests.get(
            f"{self.api_url}/connections/{connection_id}/jobs",
            headers=self.headers, params={"limit": 1}
        )
        jobs = response.json().get("jobs", [])
        if not jobs:
            return None
        job = jobs[0]
        return SyncMetrics(
            connection_id=connection_id,
            connection_name=job.get("connectionName", "Unknown"),
            status=job["status"],
            records_synced=job.get("recordsSynced", 0),
            bytes_synced=job.get("bytesSynced", 0),
            duration_seconds=(
                datetime.fromisoformat(job["endTime"]) -
                datetime.fromisoformat(job["startTime"])
            ).total_seconds() if job.get("endTime") else 0,
            start_time=datetime.fromisoformat(job["startTime"]),
        )

    def check_failed_syncs(self, since_hours: int = 24) -> List[SyncMetrics]:
        cutoff = datetime.now() - timedelta(hours=since_hours)
        failed = []
        for conn in self.get_connections():
            m = self.get_latest_sync(conn["connectionId"])
            if m and m.status == "failed" and m.start_time > cutoff:
                failed.append(m)
        return failed

    def check_stale_syncs(self, max_hours: int = 12) -> List[dict]:
        cutoff = datetime.now() - timedelta(hours=max_hours)
        stale = []
        for conn in self.get_connections():
            m = self.get_latest_sync(conn["connectionId"])
            if not m or m.start_time < cutoff:
                stale.append({"connection_id": conn["connectionId"], "name": conn["name"]})
        return stale
```

## Configuration

| Metric | Threshold | Action |
|--------|-----------|--------|
| Sync failure rate | > 10% | Alert on-call |
| Sync duration | > 2x baseline | Investigate performance |
| Records synced | 0 for 24h | Check source connectivity |
| Stale connection | No sync in 12h | Verify schedule/source |
| Schema changes | Detected | Review and approve |

## Alerting with Slack

```python
class SlackAlerter:
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url

    def alert_failed_syncs(self, failed_syncs: List[SyncMetrics]):
        if not failed_syncs:
            return
        message = f"*{len(failed_syncs)} sync(s) failed:*\n"
        for sync in failed_syncs:
            message += f"- {sync.connection_name}: {sync.status}\n"
        requests.post(self.webhook_url, json={
            "attachments": [{"color": "#ff0000", "title": "Airbyte Sync Failures", "text": message}]
        })
```

## Data Quality Checks

```python
import pandas as pd
from sqlalchemy import create_engine

class DataQualityMonitor:
    def __init__(self, conn_string: str):
        self.engine = create_engine(conn_string)

    def check_freshness(self, table: str, threshold_hours: int = 12):
        df = pd.read_sql(f"SELECT MAX(_airbyte_extracted_at) AS last_sync FROM {table}", self.engine)
        hours_old = (pd.Timestamp.now() - pd.to_datetime(df["last_sync"][0])).total_seconds() / 3600
        return {"status": "stale" if hours_old > threshold_hours else "fresh", "hours_old": hours_old}

    def check_row_count_anomaly(self, table: str, baseline: int, tolerance: float = 0.2):
        df = pd.read_sql(f"SELECT COUNT(*) AS count FROM {table}", self.engine)
        deviation = abs(df["count"][0] - baseline) / baseline
        return {"status": "anomaly" if deviation > tolerance else "normal", "current": df["count"][0]}

    def check_null_percentage(self, table: str, column: str, max_pct: float = 0.1):
        df = pd.read_sql(f"SELECT COUNT(*) AS total, SUM(CASE WHEN {column} IS NULL THEN 1 ELSE 0 END) AS nulls FROM {table}", self.engine)
        null_pct = df["nulls"][0] / df["total"][0]
        return {"status": "high_nulls" if null_pct > max_pct else "ok", "null_percentage": null_pct}
```

## Example Usage

```bash
# Cron: run every 15 minutes
*/15 * * * * /usr/bin/python3 /path/to/airbyte_monitor.py
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| No monitoring | Monitor all syncs |
| Alert fatigue (too many alerts) | Tune thresholds |
| Check manually | Automate checks |
| Ignore stale syncs | Alert on staleness |
| No data quality checks | Validate freshness/counts |

## See Also

- [connections](../concepts/connections.md)
- [api-triggered-syncs](../patterns/api-triggered-syncs.md)
