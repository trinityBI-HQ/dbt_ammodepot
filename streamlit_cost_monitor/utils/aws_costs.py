"""AWS Cost Explorer client — dual-mode credential loader.

SiS warehouse runtime:
    Credentials are read via ``_snowflake.get_generic_secret_string()``,
    a module injected by Snowflake only in the warehouse runtime.

SiS container runtime (SPCS):
    The ``_snowflake`` module is NOT available.  Snowflake exposes secrets
    bound via ``ALTER STREAMLIT SET SECRETS = ('alias' = ...)`` as env vars
    inside the container.  The variable name is the alias uppercased:
    alias ``aws_cost_explorer_creds`` → env var ``AWS_COST_EXPLORER_CREDS``.
    The value is the raw generic-string JSON:
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

from .config import (
    AWS_MONTHLY_HISTORY_MONTHS,
    AWS_RELEVANT_SERVICES,
    AWS_SECRET_NAME,
)
from .db import is_sis


@dataclass(frozen=True)
class AwsCreds:
    access_key: str
    secret_key: str


def _load_sis_creds() -> AwsCreds:
    """Load AWS creds from the Snowflake secret bound via EAI.

    Tries three mechanisms in order:
      1. ``_snowflake`` module  — injected by Snowflake in warehouse runtime.
      2. Env var exact alias    — e.g. ``aws_cost_explorer_creds`` (as written
         in the SECRETS clause, case-sensitive).
      3. Env var alias uppercased — e.g. ``AWS_COST_EXPLORER_CREDS``.

    If all fail, the RuntimeError includes every env-var KEY visible to the
    container (values are never logged) to aid diagnosis.
    """
    import os

    # 1. Warehouse runtime
    try:
        import _snowflake  # type: ignore
        raw = _snowflake.get_generic_secret_string(AWS_SECRET_NAME)
        data = json.loads(raw)
        return AwsCreds(access_key=data["access_key"], secret_key=data["secret_key"])
    except ImportError:
        pass

    # 2 + 3. Container runtime — try both casing conventions
    for env_key in (AWS_SECRET_NAME, AWS_SECRET_NAME.upper()):
        raw = os.environ.get(env_key)
        if raw:
            data = json.loads(raw)
            return AwsCreds(access_key=data["access_key"], secret_key=data["secret_key"])

    # Diagnostic: expose env-var KEYS (never values) to help identify the name
    # Snowflake chose for the mounted secret.
    all_keys = sorted(os.environ.keys())
    raise RuntimeError(
        f"Cannot load AWS credentials. "
        f"Tried env vars {AWS_SECRET_NAME!r} and {AWS_SECRET_NAME.upper()!r} — both unset. "
        f"All env var keys visible to the container: {all_keys}"
    )


@st.cache_resource
def get_boto3_client(service: str):
    """Return a boto3 client for any AWS service using the right credential source.

    SiS: credentials from Snowflake secret via env var.
    Local: default boto3 chain (AWS_PROFILE=ammodepot).
    """
    import boto3

    if is_sis():
        creds = _load_sis_creds()
        return boto3.client(
            service,
            aws_access_key_id=creds.access_key,
            aws_secret_access_key=creds.secret_key,
            region_name="us-east-1",
        )
    return boto3.client(service, region_name="us-east-1")


def get_ce_client():
    """Cost Explorer client (backward-compatible wrapper)."""
    return get_boto3_client("ce")


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
def monthly_cost_by_service(months: int = AWS_MONTHLY_HISTORY_MONTHS) -> pd.DataFrame:
    """Monthly unblended cost per service for the last N months (default 6).

    Cost Explorer's MONTHLY granularity aligns to calendar months; the
    current month is partial. The caller can decide whether to include it.
    """
    client = get_ce_client()
    today = dt.date.today()
    # Walk back `months` calendar months from the first of the current month.
    start = today.replace(day=1)
    for _ in range(months - 1):
        start = (start - dt.timedelta(days=1)).replace(day=1)
    end = today + dt.timedelta(days=1)  # CE end is exclusive

    resp = client.get_cost_and_usage(
        TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    rows: list[dict] = []
    for period in resp.get("ResultsByTime", []):
        month_start = period["TimePeriod"]["Start"]
        for group in period.get("Groups", []):
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if amount == 0:
                continue
            rows.append(
                {
                    "month": month_start,
                    "service": group["Keys"][0],
                    "dollars": round(amount, 2),
                }
            )
    df = pd.DataFrame(rows)
    if df.empty:
        return df
    df["month"] = pd.to_datetime(df["month"])
    df["relevant"] = df["service"].isin(AWS_RELEVANT_SERVICES)
    return df


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
