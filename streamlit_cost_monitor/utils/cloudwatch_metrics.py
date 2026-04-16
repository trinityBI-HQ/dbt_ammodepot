"""CloudWatch metrics + logs client for dbt pipeline monitoring.

Fetches build duration from CloudWatch Metrics (AmmoDepot/dbt namespace)
and parses build health from CloudWatch Logs (/ecs/ammodepot-dbt).

CONTRACT: Log parsing patterns match structured markers emitted by
ecs/entrypoint.sh. If the entrypoint format changes, update _parse_build_log.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

import pandas as pd
import streamlit as st

from .aws_costs import get_boto3_client
from .config import (
    CW_LOG_GROUP,
    CW_METRIC_LOOKBACK_DAYS,
    CW_METRIC_NAME,
    CW_NAMESPACE,
    DBT_DOCS_S3_BUCKET,
    DBT_DOCS_S3_KEY,
)

_CACHE_TTL = 300  # 5 min — metric publishes every ~10 min


@st.cache_data(ttl=_CACHE_TTL, show_spinner=False)
def build_duration_timeseries(days: int = CW_METRIC_LOOKBACK_DAYS) -> pd.DataFrame:
    """Fetch BuildDurationMinutes from CloudWatch for the last N days."""
    client = get_boto3_client("cloudwatch")
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=days)

    resp = client.get_metric_data(
        MetricDataQueries=[
            {
                "Id": "duration",
                "MetricStat": {
                    "Metric": {
                        "Namespace": CW_NAMESPACE,
                        "MetricName": CW_METRIC_NAME,
                    },
                    "Period": 600,  # 10-min aligned with EventBridge schedule
                    "Stat": "Average",
                },
                "ReturnData": True,
            }
        ],
        StartTime=start,
        EndTime=end,
        ScanBy="TimestampAscending",
    )

    values = resp["MetricDataResults"][0]
    if not values["Timestamps"]:
        return pd.DataFrame(columns=["timestamp", "duration_min"])

    return pd.DataFrame(
        {
            "timestamp": values["Timestamps"],
            "duration_min": values["Values"],
        }
    )


@st.cache_data(ttl=_CACHE_TTL, show_spinner=False)
def recent_builds(limit: int = 25) -> pd.DataFrame:
    """Parse recent dbt builds from CloudWatch Logs.

    Each ECS task run is a log stream. We fetch the most recent streams
    and extract structured markers from each.
    """
    client = get_boto3_client("logs")

    streams_resp = client.describe_log_streams(
        logGroupName=CW_LOG_GROUP,
        orderBy="LastEventTime",
        descending=True,
        limit=limit,
    )

    builds = []
    for stream in streams_resp.get("logStreams", []):
        if "lastEventTimestamp" not in stream:
            continue
        events = client.get_log_events(
            logGroupName=CW_LOG_GROUP,
            logStreamName=stream["logStreamName"],
            startFromHead=True,
        )
        text = "\n".join(e["message"] for e in events.get("events", []))
        builds.append(_parse_build_log(text, stream))

    if not builds:
        return pd.DataFrame(
            columns=[
                "Timestamp",
                "Status",
                "Duration (min)",
                "Iceberg (s)",
                "Pass",
                "Warn",
                "Error",
            ]
        )
    return pd.DataFrame(builds)


def _parse_build_log(text: str, stream: dict) -> dict:
    """Extract structured markers from a single build log.

    CONTRACT: These patterns match markers emitted by ecs/entrypoint.sh.
    If the entrypoint format changes, update these patterns.
    """
    ts = datetime.fromtimestamp(
        stream.get("lastEventTimestamp", 0) / 1000, tz=timezone.utc
    )

    duration = _extract(r"BUILD_DURATION_MINUTES=(\d+\.?\d*)", text)
    iceberg = _extract(r"ICEBERG_REFRESH_SECONDS=(\d+)", text)

    # dbt summary line: "Done. PASS=363 WARN=11 ERROR=0"
    pass_count = _extract(r"PASS=(\d+)", text)
    warn_count = _extract(r"WARN=(\d+)", text)
    error_count = _extract(r"ERROR=(\d+)", text)

    # Build failed if ANSI red ERROR present or error_count > 0
    has_error = "\x1b[31mERROR" in text or (
        error_count is not None and int(error_count) > 0
    )

    return {
        "Timestamp": ts.strftime("%Y-%m-%d %H:%M UTC"),
        "Status": "FAIL" if has_error else "PASS",
        "Duration (min)": round(float(duration), 1) if duration else None,
        "Iceberg (s)": int(iceberg) if iceberg else None,
        "Pass": int(pass_count) if pass_count else None,
        "Warn": int(warn_count) if warn_count else None,
        "Error": int(error_count) if error_count else None,
    }


def _extract(pattern: str, text: str) -> str | None:
    m = re.search(pattern, text)
    return m.group(1) if m else None


@st.cache_data(ttl=3600, show_spinner=False)
def dbt_docs_presigned_url() -> str | None:
    """Generate a 1-hour presigned URL for the dbt docs static HTML in S3.

    generate_presigned_url is a local signing operation — no network call.
    The URL is valid as long as the IAM creds have s3:GetObject and the
    object exists (CI uploads on every ammodepot/ push).
    """
    try:
        client = get_boto3_client("s3")
        return client.generate_presigned_url(
            "get_object",
            Params={"Bucket": DBT_DOCS_S3_BUCKET, "Key": DBT_DOCS_S3_KEY},
            ExpiresIn=3600,
        )
    except Exception:  # noqa: BLE001
        return None
