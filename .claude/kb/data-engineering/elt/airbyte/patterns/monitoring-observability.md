# Monitoring and Observability

> **Purpose**: Monitor Airbyte sync health, performance, and data quality
> **MCP Validated**: 2026-02-19

## When to Use

- Production Airbyte deployments requiring uptime SLAs
- Need alerting on sync failures or data quality issues
- Track sync performance and optimize costs
- Detect schema drift or data anomalies
- Maintain audit logs for compliance

## Implementation

### Prometheus + Grafana (OSS)

```yaml
# docker-compose.yml additions for monitoring
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

# prometheus.yml
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'airbyte'
    static_configs:
      - targets: ['airbyte-server:8001']
    metrics_path: '/api/v1/health'
```

### Python Monitoring Script

```python
# monitoring/airbyte_monitor.py
import requests
import time
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
    end_time: datetime

class AirbyteMonitor:
    def __init__(self, api_url: str, api_key: str):
        self.api_url = api_url
        self.headers = {"Authorization": f"Bearer {api_key}"}

    def get_connections(self) -> List[dict]:
        """Fetch all connections."""
        response = requests.get(
            f"{self.api_url}/connections",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()["connections"]

    def get_latest_sync_metrics(
        self, connection_id: str
    ) -> Optional[SyncMetrics]:
        """Get metrics for the most recent sync."""
        response = requests.get(
            f"{self.api_url}/connections/{connection_id}/jobs",
            headers=self.headers,
            params={"limit": 1}
        )
        response.raise_for_status()

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
            end_time=datetime.fromisoformat(job["endTime"])
                if job.get("endTime") else None,
        )

    def check_failed_syncs(
        self, since_hours: int = 24
    ) -> List[SyncMetrics]:
        """Find failed syncs in the last N hours."""
        failed_syncs = []
        cutoff_time = datetime.now() - timedelta(hours=since_hours)

        connections = self.get_connections()
        for conn in connections:
            metrics = self.get_latest_sync_metrics(conn["connectionId"])
            if (
                metrics
                and metrics.status == "failed"
                and metrics.start_time > cutoff_time
            ):
                failed_syncs.append(metrics)

        return failed_syncs

    def check_stale_syncs(
        self, max_hours_since_sync: int = 12
    ) -> List[dict]:
        """Find connections that haven't synced recently."""
        stale_connections = []
        cutoff_time = datetime.now() - timedelta(hours=max_hours_since_sync)

        connections = self.get_connections()
        for conn in connections:
            metrics = self.get_latest_sync_metrics(conn["connectionId"])
            if not metrics or metrics.start_time < cutoff_time:
                stale_connections.append({
                    "connection_id": conn["connectionId"],
                    "name": conn["name"],
                    "last_sync": metrics.start_time if metrics else None,
                })

        return stale_connections

    def export_metrics_to_prometheus(self, output_file: str):
        """Export metrics in Prometheus format."""
        connections = self.get_connections()
        metrics_lines = []

        for conn in connections:
            metrics = self.get_latest_sync_metrics(conn["connectionId"])
            if not metrics:
                continue

            # Prometheus metric format
            labels = f'connection_id="{metrics.connection_id}",name="{metrics.connection_name}"'

            metrics_lines.extend([
                f'airbyte_sync_records_total{{{labels}}} {metrics.records_synced}',
                f'airbyte_sync_bytes_total{{{labels}}} {metrics.bytes_synced}',
                f'airbyte_sync_duration_seconds{{{labels}}} {metrics.duration_seconds}',
                f'airbyte_sync_status{{{labels},status="{metrics.status}"}} 1',
            ])

        with open(output_file, 'w') as f:
            f.write('\n'.join(metrics_lines))

# Usage
if __name__ == "__main__":
    monitor = AirbyteMonitor(
        api_url="https://api.airbyte.com/v1",
        api_key="your-api-key"
    )

    # Check for failures
    failed = monitor.check_failed_syncs(since_hours=24)
    if failed:
        print(f"Found {len(failed)} failed syncs:")
        for sync in failed:
            print(f"  - {sync.connection_name}: {sync.status}")

    # Check for stale syncs
    stale = monitor.check_stale_syncs(max_hours_since_sync=12)
    if stale:
        print(f"Found {len(stale)} stale connections")

    # Export to Prometheus
    monitor.export_metrics_to_prometheus("/tmp/airbyte_metrics.prom")
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
# monitoring/slack_alerter.py
import requests
from typing import List
from airbyte_monitor import SyncMetrics

class SlackAlerter:
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url

    def send_alert(
        self, title: str, message: str, severity: str = "warning"
    ):
        """Send alert to Slack."""
        color = {
            "critical": "#ff0000",
            "warning": "#ffaa00",
            "info": "#00ff00",
        }.get(severity, "#cccccc")

        payload = {
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "text": message,
                    "footer": "Airbyte Monitor",
                    "ts": int(time.time()),
                }
            ]
        }

        requests.post(self.webhook_url, json=payload)

    def alert_failed_syncs(self, failed_syncs: List[SyncMetrics]):
        """Alert on failed syncs."""
        if not failed_syncs:
            return

        message = f"*{len(failed_syncs)} sync(s) failed:*\n"
        for sync in failed_syncs:
            message += f"• {sync.connection_name} - {sync.status}\n"

        self.send_alert(
            title="Airbyte Sync Failures",
            message=message,
            severity="critical"
        )

# Cron job to check and alert
if __name__ == "__main__":
    monitor = AirbyteMonitor(api_url=API_URL, api_key=API_KEY)
    alerter = SlackAlerter(webhook_url=SLACK_WEBHOOK)

    failed = monitor.check_failed_syncs(since_hours=1)
    if failed:
        alerter.alert_failed_syncs(failed)
```

## Data Quality Monitoring

```python
# monitoring/data_quality.py
import pandas as pd
from sqlalchemy import create_engine

class DataQualityMonitor:
    def __init__(self, snowflake_conn_string: str):
        self.engine = create_engine(snowflake_conn_string)

    def check_freshness(self, table: str, threshold_hours: int = 12):
        """Check if data is fresh."""
        query = f"""
        SELECT MAX(_airbyte_extracted_at) AS last_sync
        FROM {table}
        """
        df = pd.read_sql(query, self.engine)
        last_sync = pd.to_datetime(df["last_sync"][0])
        hours_old = (pd.Timestamp.now() - last_sync).total_seconds() / 3600

        if hours_old > threshold_hours:
            return {
                "status": "stale",
                "hours_old": hours_old,
                "last_sync": last_sync,
            }
        return {"status": "fresh", "hours_old": hours_old}

    def check_row_count_anomaly(
        self, table: str, baseline_count: int, tolerance: float = 0.2
    ):
        """Detect anomalous row counts."""
        query = f"SELECT COUNT(*) AS count FROM {table}"
        df = pd.read_sql(query, self.engine)
        current_count = df["count"][0]

        deviation = abs(current_count - baseline_count) / baseline_count

        if deviation > tolerance:
            return {
                "status": "anomaly",
                "current": current_count,
                "baseline": baseline_count,
                "deviation": deviation,
            }
        return {"status": "normal", "current": current_count}

    def check_null_percentage(
        self, table: str, column: str, max_null_pct: float = 0.1
    ):
        """Check for excessive nulls."""
        query = f"""
        SELECT
          COUNT(*) AS total,
          SUM(CASE WHEN {column} IS NULL THEN 1 ELSE 0 END) AS nulls
        FROM {table}
        """
        df = pd.read_sql(query, self.engine)
        null_pct = df["nulls"][0] / df["total"][0]

        if null_pct > max_null_pct:
            return {
                "status": "high_nulls",
                "null_percentage": null_pct,
                "column": column,
            }
        return {"status": "ok", "null_percentage": null_pct}
```

## Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Airbyte Monitoring",
    "panels": [
      {
        "title": "Sync Success Rate (24h)",
        "targets": [
          {
            "expr": "sum(rate(airbyte_sync_status{status=\"succeeded\"}[24h])) / sum(rate(airbyte_sync_status[24h]))"
          }
        ]
      },
      {
        "title": "Records Synced per Connection",
        "targets": [
          {
            "expr": "sum by (name) (airbyte_sync_records_total)"
          }
        ]
      },
      {
        "title": "Average Sync Duration",
        "targets": [
          {
            "expr": "avg(airbyte_sync_duration_seconds) by (name)"
          }
        ]
      }
    ]
  }
}
```

## Example Usage

```bash
# Run monitoring script via cron
# crontab -e
*/15 * * * * /usr/bin/python3 /path/to/airbyte_monitor.py

# Docker-based monitoring
docker-compose up -d prometheus grafana

# Access Grafana dashboard
open http://localhost:3000
```

## Schema Change Detection

```python
def detect_schema_changes(connection_id: str):
    """Detect schema changes in a connection."""
    response = requests.get(
        f"{AIRBYTE_API}/connections/{connection_id}/catalog",
        headers=headers
    )
    current_catalog = response.json()

    # Compare with stored catalog
    with open(f"catalogs/{connection_id}.json", "r") as f:
        previous_catalog = json.load(f)

    changes = []
    for stream in current_catalog["streams"]:
        prev_stream = next(
            (s for s in previous_catalog["streams"]
             if s["name"] == stream["name"]),
            None
        )

        if not prev_stream:
            changes.append(f"New stream: {stream['name']}")
            continue

        # Check for field changes
        current_fields = set(stream["jsonSchema"]["properties"].keys())
        previous_fields = set(prev_stream["jsonSchema"]["properties"].keys())

        added = current_fields - previous_fields
        removed = previous_fields - current_fields

        if added:
            changes.append(f"Fields added to {stream['name']}: {added}")
        if removed:
            changes.append(f"Fields removed from {stream['name']}: {removed}")

    return changes
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
- [cloud-vs-oss](../concepts/cloud-vs-oss.md)
