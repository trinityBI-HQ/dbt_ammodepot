"""AWS Cost Explorer client — dual-mode credential loader.

SiS container runtime:
    Credentials live in a Snowflake generic-string secret called
    ``aws_cost_explorer_creds`` attached to the Streamlit app via an
    External Access Integration.  The secret value is a JSON string
    ``{"access_key": "...", "secret_key": "..."}``.

Local dev:
    Uses the default boto3 credential chain — typically
    ``AWS_PROFILE=ammodepot`` from the shell environment.

Cost Explorer API charges $0.01 per request, so every call is wrapped in
a 6-hour Streamlit cache.  That keeps the monthly API cost well under $1
even if the dashboard is reopened hundreds of times.
"""

from __future__ import annotations

import datetime as dt
import json
from dataclasses import dataclass

import pandas as pd
import streamlit as st

from .config import AWS_RELEVANT_SERVICES, AWS_SECRET_NAME
from .db import is_sis


@dataclass(frozen=True)
class AwsCreds:
    access_key: str
    secret_key: str


def _load_sis_creds() -> AwsCreds:
    """Load AWS creds from the Snowflake secret bound via EAI."""
    import _snowflake  # type: ignore  # only available in SiS container runtime

    raw = _snowflake.get_generic_secret_string(AWS_SECRET_NAME)
    data = json.loads(raw)
    return AwsCreds(access_key=data["access_key"], secret_key=data["secret_key"])


@st.cache_resource
def get_ce_client():
    """Return a boto3 ``ce`` client using the right credential source."""
    import boto3

    if is_sis():
        creds = _load_sis_creds()
        return boto3.client(
            "ce",
            aws_access_key_id=creds.access_key,
            aws_secret_access_key=creds.secret_key,
            region_name="us-east-1",
        )
    # Local dev: fall through to default chain (AWS_PROFILE=ammodepot).
    return boto3.client("ce", region_name="us-east-1")


# --------------------------------------------------------------------------- #
# Cached queries
# --------------------------------------------------------------------------- #

_CACHE_TTL = 6 * 60 * 60  # 6 hours


def _month_start(date: dt.date) -> dt.date:
    return date.replace(day=1)


@st.cache_data(ttl=_CACHE_TTL, show_spinner=False)
def daily_cost_by_service(days: int = 90) -> pd.DataFrame:
    """Unblended cost per day, grouped by AWS service.

    Filters client-side to services relevant to the pipeline. Cost Explorer
    can filter server-side but only on exact-match or tag dimensions.
    """
    client = get_ce_client()
    end = dt.date.today() + dt.timedelta(days=1)  # CE End is exclusive
    start = end - dt.timedelta(days=days)

    rows: list[dict] = []
    next_token: str | None = None
    while True:
        kwargs = dict(
            TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
        if next_token:
            kwargs["NextPageToken"] = next_token  # type: ignore[assignment]
        resp = client.get_cost_and_usage(**kwargs)
        for day in resp.get("ResultsByTime", []):
            usage_date = day["TimePeriod"]["Start"]
            for group in day.get("Groups", []):
                service = group["Keys"][0]
                amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
                if amount == 0:
                    continue
                rows.append({"usage_date": usage_date, "service": service, "dollars": amount})
        next_token = resp.get("NextPageToken")
        if not next_token:
            break

    df = pd.DataFrame(rows)
    if df.empty:
        return df
    df["usage_date"] = pd.to_datetime(df["usage_date"])
    df["relevant"] = df["service"].isin(AWS_RELEVANT_SERVICES)
    return df


@st.cache_data(ttl=_CACHE_TTL, show_spinner=False)
def mtd_summary_aws() -> dict:
    """MTD unblended cost + equivalent prior-month MTD-to-date."""
    client = get_ce_client()
    today = dt.date.today()
    month_start = _month_start(today)
    prior_month_start = _month_start(month_start - dt.timedelta(days=1))
    prior_same_day = prior_month_start + (today - month_start)

    def _total(start: dt.date, end: dt.date) -> float:
        # CE End is exclusive — caller guarantees end > start.
        if end <= start:
            return 0.0
        resp = client.get_cost_and_usage(
            TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
            Granularity="MONTHLY",
            Metrics=["UnblendedCost"],
        )
        total = 0.0
        for period in resp.get("ResultsByTime", []):
            total += float(period["Total"]["UnblendedCost"]["Amount"])
        return total

    mtd = _total(month_start, today + dt.timedelta(days=1))
    prior = _total(prior_month_start, prior_same_day + dt.timedelta(days=1))
    return {
        "dollars_mtd": round(mtd, 2),
        "dollars_prior_mtd": round(prior, 2),
        "delta_pct": round(((mtd - prior) / prior * 100.0), 1) if prior else None,
        "days_elapsed": (today - month_start).days + 1,
    }


@st.cache_data(ttl=_CACHE_TTL, show_spinner=False)
def cost_by_service_mtd() -> pd.DataFrame:
    client = get_ce_client()
    today = dt.date.today()
    month_start = _month_start(today)
    resp = client.get_cost_and_usage(
        TimePeriod={
            "Start": month_start.isoformat(),
            "End": (today + dt.timedelta(days=1)).isoformat(),
        },
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    rows = []
    for period in resp.get("ResultsByTime", []):
        for group in period.get("Groups", []):
            rows.append(
                {
                    "service": group["Keys"][0],
                    "dollars": round(float(group["Metrics"]["UnblendedCost"]["Amount"]), 2),
                }
            )
    df = pd.DataFrame(rows)
    if df.empty:
        return df
    df["relevant"] = df["service"].isin(AWS_RELEVANT_SERVICES)
    return df.sort_values("dollars", ascending=False).reset_index(drop=True)
