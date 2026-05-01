"""Page 4 — Combined Snowflake + AWS monthly cost view."""

import datetime as dt

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from utils.aws_costs import (
    cost_by_service_mtd,
    monthly_cost_by_service,
    mtd_summary_aws,
)
from utils.chart_theme import ACCENT, WARNING, apply_theme, dark_dataframe, kpi_card
from utils.config import AWS_MONTHLY_HISTORY_MONTHS, AWS_RELEVANT_SERVICES
from utils.db import run_query
from utils.snowflake_queries import monthly_cost_by_warehouse, mtd_summary

st.set_page_config(page_title="Combined Cost", layout="wide")
st.title("Combined Pipeline Cost — Snowflake + AWS")
st.caption("Single source of truth for month-to-date pipeline spend.")

# --------------------------------------------------------------------------- #
# MTD load (KPI row)
# --------------------------------------------------------------------------- #

sf = run_query(mtd_summary()).iloc[0]
sf_mtd = float(sf["DOLLARS_MTD"] or 0)
sf_prior = float(sf["DOLLARS_PRIOR_MTD"] or 0)

aws_ok = True
aws_services_df = pd.DataFrame()
try:
    aws = mtd_summary_aws()
    aws_mtd_total = float(aws["dollars_mtd"])
    aws_prior_total = float(aws["dollars_prior_mtd"])
    aws_services_df = cost_by_service_mtd()
except Exception as exc:  # noqa: BLE001
    st.warning(
        "AWS data unavailable — showing Snowflake only. "
        "Fix the External Access Integration if you expect AWS numbers here."
    )
    st.exception(exc)
    aws_mtd_total = 0.0
    aws_prior_total = 0.0
    aws_ok = False

# "AWS infrastructure" = sum of services on the allow-list (see bottom of page).
if aws_ok and not aws_services_df.empty:
    relevant_services = aws_services_df[aws_services_df["relevant"]].copy()
    aws_mtd = float(relevant_services["dollars"].sum())
    # Scale prior-month total by the current-month relevant/total ratio so
    # the comparison is apples-to-apples (CE doesn't give us "prior month
    # by service" without another API call).
    if aws_mtd_total > 0:
        ratio = aws_mtd / aws_mtd_total
        aws_prior = aws_prior_total * ratio
    else:
        aws_prior = 0.0
else:
    relevant_services = pd.DataFrame()
    aws_mtd = 0.0
    aws_prior = 0.0

total_mtd = sf_mtd + aws_mtd
total_prior = sf_prior + aws_prior
delta = total_mtd - total_prior
delta_pct = (delta / total_prior * 100.0) if total_prior else None

k1, k2, k3, k4 = st.columns(4)
with k1:
    kpi_card("Total MTD (pipeline)", f"${total_mtd:,.0f}")
with k2:
    kpi_card("Snowflake compute", f"${sf_mtd:,.0f}")
with k3:
    kpi_card("AWS infrastructure", f"${aws_mtd:,.0f}" if aws_ok else "—")
with k4:
    if delta_pct is None:
        kpi_card("vs Prior Month", "—")
    else:
        arrow = "▲" if delta > 0 else "▼"
        kpi_card(
            "vs Prior Month",
            f"${abs(delta):,.0f}",
            delta=f"{arrow} {abs(delta_pct):.1f}%",
            delta_color="inverse",
        )

st.divider()

# --------------------------------------------------------------------------- #
# 6-month stacked monthly cost (Snowflake + AWS)
# --------------------------------------------------------------------------- #

st.subheader(f"Monthly Cost ({AWS_MONTHLY_HISTORY_MONTHS}M)")
st.caption(
    "Calendar-month totals, Snowflake compute + AWS infrastructure. "
    "The most recent bucket is **the current month so far** — "
    "compare it to prior **full** months with that caveat in mind."
)

show_all_monthly = st.checkbox(
    "Show all services (not just pipeline-relevant)",
    value=False,
    key="combined_monthly_show_all",
    help=(
        "By default the AWS bar only counts services used by the analytics "
        "pipeline (`AWS_RELEVANT_SERVICES` in `utils/config.py`). Toggle on to "
        "include every AWS service billed in the window."
    ),
)

# --- Snowflake monthly totals -------------------------------------------------
sf_monthly_raw = run_query(monthly_cost_by_warehouse(AWS_MONTHLY_HISTORY_MONTHS))
if not sf_monthly_raw.empty:
    sf_monthly = (
        sf_monthly_raw.groupby("MONTH")["DOLLARS"]
        .sum()
        .reset_index()
        .rename(columns={"MONTH": "month", "DOLLARS": "dollars"})
    )
    sf_monthly["month"] = pd.to_datetime(sf_monthly["month"])
else:
    sf_monthly = pd.DataFrame(columns=["month", "dollars"])

# --- AWS monthly totals (relevant services only) -----------------------------
if aws_ok:
    try:
        aws_monthly_raw = monthly_cost_by_service(AWS_MONTHLY_HISTORY_MONTHS)
    except Exception as exc:  # noqa: BLE001
        st.warning("Couldn't load AWS monthly trend — showing Snowflake only.")
        st.exception(exc)
        aws_monthly_raw = pd.DataFrame()
else:
    aws_monthly_raw = pd.DataFrame()

if not aws_monthly_raw.empty:
    aws_filtered = (
        aws_monthly_raw if show_all_monthly else aws_monthly_raw[aws_monthly_raw["relevant"]]
    )
    aws_monthly = (
        aws_filtered.groupby("month")["dollars"].sum().reset_index()
    )
else:
    aws_monthly = pd.DataFrame(columns=["month", "dollars"])

# --- Merge on month and plot --------------------------------------------------
if sf_monthly.empty and aws_monthly.empty:
    st.info("No monthly cost data available.")
else:
    # Build the full month axis from the earliest month on either side.
    today = dt.date.today()
    month_start = today.replace(day=1)
    months = [month_start]
    for _ in range(AWS_MONTHLY_HISTORY_MONTHS - 1):
        months.append((months[-1] - dt.timedelta(days=1)).replace(day=1))
    months = sorted(m for m in months)
    axis = pd.DataFrame({"month": pd.to_datetime(months)})

    merged = (
        axis.merge(
            sf_monthly.rename(columns={"dollars": "snowflake"}),
            on="month",
            how="left",
        )
        .merge(
            aws_monthly.rename(columns={"dollars": "aws"}),
            on="month",
            how="left",
        )
        .fillna(0.0)
    )
    merged["total"] = merged["snowflake"] + merged["aws"]

    # Mark the current month as partial in the x-axis label.
    current_month_ts = pd.to_datetime(month_start)
    def _label(ts):
        s = ts.strftime("%b %Y")
        return f"{s} (partial)" if ts == current_month_ts else s
    labels = [_label(ts) for ts in merged["month"]]

    fig = go.Figure()
    fig.add_trace(
        go.Bar(
            x=labels,
            y=merged["snowflake"].astype(float).tolist(),
            name="Snowflake compute",
            marker_color=ACCENT,
            hovertemplate="%{x}<br>Snowflake: $%{y:,.2f}<extra></extra>",
        )
    )
    fig.add_trace(
        go.Bar(
            x=labels,
            y=merged["aws"].astype(float).tolist(),
            name="AWS infrastructure",
            marker_color=WARNING,
            hovertemplate="%{x}<br>AWS: $%{y:,.2f}<extra></extra>",
        )
    )
    # Total label above each stack.
    fig.add_trace(
        go.Scatter(
            x=labels,
            y=merged["total"].astype(float).tolist(),
            mode="text",
            text=[f"${v:,.0f}" for v in merged["total"]],
            textposition="top center",
            textfont=dict(color="#e0e0e0", size=12),
            showlegend=False,
            hoverinfo="skip",
        )
    )
    fig.update_layout(barmode="stack")
    fig.update_yaxes(tickprefix="$", tickformat=",.0f")
    apply_theme(fig, height=400)
    st.plotly_chart(fig, width="stretch", theme=None)

    # Sanity-check table under the chart.
    totals_df = merged.copy()
    totals_df["Month"] = labels
    totals_df = totals_df.rename(
        columns={
            "snowflake": "Snowflake $",
            "aws": "AWS $",
            "total": "Total $",
        }
    )[["Month", "Snowflake $", "AWS $", "Total $"]]
    dark_dataframe(
        totals_df,
        fmt={
            "Snowflake $": "${:,.2f}",
            "AWS $": "${:,.2f}",
            "Total $": "${:,.2f}",
        },
    )

st.divider()

# --------------------------------------------------------------------------- #
# What counts as "AWS infrastructure" — the whole point of this section
# --------------------------------------------------------------------------- #

st.subheader("What counts as AWS infrastructure?")
st.caption(
    "These are the AWS services the analytics pipeline actively uses. "
    "Any other service (RDS, ELB, personal sandboxes, Redshift if it "
    "leaked past decommissioning) is **excluded** from the Combined view "
    "but visible on the AWS Infrastructure page under *Show all services*. "
    "Edit the allow-list in `utils/config.py` → `AWS_RELEVANT_SERVICES`."
)

allowlist_df = pd.DataFrame({"service": list(AWS_RELEVANT_SERVICES)})
if not relevant_services.empty:
    allowlist_df = allowlist_df.merge(
        relevant_services[["service", "dollars"]], on="service", how="left"
    )
else:
    allowlist_df["dollars"] = 0.0
allowlist_df["dollars"] = allowlist_df["dollars"].fillna(0.0)
allowlist_df = allowlist_df.sort_values("dollars", ascending=False).reset_index(drop=True)
allowlist_df["Counted MTD?"] = allowlist_df["dollars"].apply(
    lambda d: "yes" if d > 0 else "—"
)

display = allowlist_df.rename(
    columns={"service": "AWS Service", "dollars": "MTD $"}
)[["AWS Service", "MTD $", "Counted MTD?"]]
dark_dataframe(display, fmt={"MTD $": "${:,.2f}"})

if aws_ok and aws_mtd_total > 0:
    excluded = aws_mtd_total - aws_mtd
    st.caption(
        f"**Excluded from Combined view**: ${excluded:,.2f} MTD from non-pipeline "
        f"services. See the AWS Infrastructure page → *Show all services* for detail."
    )

st.caption(
    "*Snowflake side uses `CREDIT_PRICE_USD` from `utils/config.py`. "
    "AWS side is unblended cost from Cost Explorer (excludes credits/refunds).*"
)
