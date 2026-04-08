"""Page 1 — Snowflake compute spend (MTD + 90-day trend + breakdowns)."""

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from utils.chart_theme import ACCENT, WARNING, apply_theme, dark_dataframe, kpi_card
from utils.db import run_query
from utils.snowflake_queries import (
    cost_anomalies,
    cost_by_query_tag_mtd,
    cost_by_user_mtd,
    cost_by_warehouse_mtd,
    daily_cost_by_user,
    daily_cost_by_warehouse,
    mtd_summary,
)

st.set_page_config(page_title="Snowflake Compute", layout="wide")
st.title("Snowflake Compute")
st.caption(
    "Compute credits converted to dollars at the rate in "
    "`utils/config.py` (`CREDIT_PRICE_USD`)."
)

# --------------------------------------------------------------------------- #
# KPI row
# --------------------------------------------------------------------------- #

summary = run_query(mtd_summary()).iloc[0]
mtd_dollars = float(summary["DOLLARS_MTD"] or 0)
prior_dollars = float(summary["DOLLARS_PRIOR_MTD"] or 0)
delta = mtd_dollars - prior_dollars
delta_pct = (delta / prior_dollars * 100.0) if prior_dollars else None

k1, k2, k3, k4 = st.columns(4)
with k1:
    kpi_card("Spend MTD", f"${mtd_dollars:,.0f}")
with k2:
    kpi_card("Credits MTD", f"{float(summary['CREDITS_MTD'] or 0):,.0f}")
with k3:
    label = "vs Prior Month (same day)"
    if delta_pct is None:
        kpi_card(label, "—")
    else:
        arrow = "▲" if delta > 0 else "▼"
        kpi_card(
            label,
            f"${abs(delta):,.0f}",
            delta=f"{arrow} {abs(delta_pct):.1f}%",
            delta_color="inverse",
        )
with k4:
    kpi_card("Days Elapsed", f"{int(summary['DAYS_ELAPSED'])}")

st.divider()

# --------------------------------------------------------------------------- #
# Daily cost trend
# --------------------------------------------------------------------------- #

st.subheader("Daily Spend by Warehouse (90d)")
daily = run_query(daily_cost_by_warehouse())
if daily.empty:
    st.info("No compute activity in the last 90 days.")
else:
    pivot = daily.pivot_table(
        index="USAGE_DATE", columns="WAREHOUSE_NAME", values="DOLLARS", aggfunc="sum"
    ).fillna(0)
    fig = go.Figure()
    for col in pivot.columns:
        fig.add_trace(
            go.Scatter(
                x=pivot.index.tolist(),
                y=pivot[col].tolist(),
                mode="lines",
                name=col,
                hovertemplate="%{x|%Y-%m-%d}<br>" + col + ": $%{y:,.2f}<extra></extra>",
            )
        )
    fig.update_yaxes(tickprefix="$", tickformat=",.0f")
    apply_theme(fig, height=360)
    st.plotly_chart(fig, width="stretch", theme=None)

st.divider()

# --------------------------------------------------------------------------- #
# Daily spend by user (top-5 + Other), stacked
# --------------------------------------------------------------------------- #

st.subheader("Daily Spend by User (90d)")
st.caption(
    "Hourly credits allocated to users by execution_time share. Top-5 users "
    "by total window spend get their own line; everyone else rolls into *Other*."
)

user_daily = run_query(daily_cost_by_user())
if user_daily.empty:
    st.info("No user query activity in the last 90 days.")
else:
    pivot_u = user_daily.pivot_table(
        index="USAGE_DATE", columns="BUCKET", values="DOLLARS", aggfunc="sum"
    ).fillna(0)
    # Legend order: biggest spenders first, Other last.
    cols = sorted(
        [c for c in pivot_u.columns if c != "Other"],
        key=lambda c: pivot_u[c].sum(),
        reverse=True,
    ) + (["Other"] if "Other" in pivot_u.columns else [])
    pivot_u = pivot_u[cols]

    fig = go.Figure()
    for col in pivot_u.columns:
        fig.add_trace(
            go.Scatter(
                x=pivot_u.index.tolist(),
                y=pivot_u[col].tolist(),
                mode="lines",
                name=col,
                hovertemplate="%{x|%Y-%m-%d}<br>" + col + ": $%{y:,.2f}<extra></extra>",
            )
        )
    fig.update_yaxes(tickprefix="$", tickformat=",.0f")
    apply_theme(fig, height=360)
    st.plotly_chart(fig, width="stretch", theme=None)

st.divider()

# --------------------------------------------------------------------------- #
# Dimensional breakdowns
# --------------------------------------------------------------------------- #

st.subheader("MTD Breakdown")

col_wh, col_user = st.columns(2)

with col_wh:
    st.markdown("**By Warehouse**")
    wh = run_query(cost_by_warehouse_mtd())
    if wh.empty:
        st.info("No spend MTD.")
    else:
        fig = go.Figure(
            go.Bar(
                x=wh["DOLLARS"].astype(float).tolist(),
                y=wh["WAREHOUSE_NAME"].tolist(),
                orientation="h",
                marker_color=ACCENT,
                text=[f"${v:,.0f}" for v in wh["DOLLARS"].astype(float)],
                textposition="outside",
                hovertemplate="%{y}: $%{x:,.2f}<extra></extra>",
            )
        )
        fig.update_yaxes(autorange="reversed")
        fig.update_xaxes(tickprefix="$", tickformat=",.0f")
        apply_theme(fig, height=320, show_legend=False)
        st.plotly_chart(fig, width="stretch", theme=None)

with col_user:
    st.markdown("**By User**")
    users = run_query(cost_by_user_mtd())
    if users.empty:
        st.info("No query activity MTD.")
    else:
        top_users = users.head(10)
        fig = go.Figure(
            go.Bar(
                x=top_users["DOLLARS"].astype(float).tolist(),
                y=top_users["USER_NAME"].tolist(),
                orientation="h",
                marker_color=ACCENT,
                text=[f"${v:,.0f}" for v in top_users["DOLLARS"].astype(float)],
                textposition="outside",
                hovertemplate="%{y}: $%{x:,.2f}<extra></extra>",
            )
        )
        fig.update_yaxes(autorange="reversed")
        fig.update_xaxes(tickprefix="$", tickformat=",.0f")
        apply_theme(fig, height=320, show_legend=False)
        st.plotly_chart(fig, width="stretch", theme=None)

st.markdown("**By Query Tag**")
st.caption(
    "All dbt runs are tagged via QUERY_TAG — use this to separate dbt spend "
    "from Airbyte inserts, Streamlit sessions, and ad-hoc queries."
)
tags = run_query(cost_by_query_tag_mtd())
if tags.empty:
    st.info("No tagged queries MTD.")
else:
    fig = go.Figure(
        go.Bar(
            x=tags["DOLLARS"].astype(float).tolist(),
            y=tags["QUERY_TAG"].tolist(),
            orientation="h",
            marker_color=WARNING,
            text=[f"${v:,.0f}" for v in tags["DOLLARS"].astype(float)],
            textposition="outside",
            hovertemplate="%{y}: $%{x:,.2f}<extra></extra>",
        )
    )
    fig.update_yaxes(autorange="reversed")
    fig.update_xaxes(tickprefix="$", tickformat=",.0f")
    apply_theme(fig, height=max(240, 28 * len(tags)), show_legend=False)
    st.plotly_chart(fig, width="stretch", theme=None)

st.divider()

# --------------------------------------------------------------------------- #
# Daily anomaly detector
# --------------------------------------------------------------------------- #

st.subheader("Daily Cost Anomalies (30d)")
st.caption(
    "Flagged when daily spend exceeds 2.5× the 28-day rolling mean. "
    "Tune the multiplier in `utils/config.py`."
)

anomalies = run_query(cost_anomalies())
if anomalies.empty:
    st.info("No anomaly history yet (needs at least 7 days of data).")
else:
    flagged = anomalies[anomalies["STATUS"] == "ANOMALY"]
    if len(flagged) == 0:
        st.success("No anomalies in the last 30 days.")
    else:
        st.error(f"{len(flagged)} anomalous day(s) detected.")
    display = anomalies.rename(
        columns={
            "USAGE_DATE": "Date",
            "CREDITS": "Credits",
            "DOLLARS": "Dollars",
            "BASELINE_28D_CREDITS": "Baseline 28d (credits)",
            "STATUS": "Status",
        }
    )
    dark_dataframe(
        display,
        fmt={
            "Credits": "{:,.2f}",
            "Dollars": "${:,.2f}",
            "Baseline 28d (credits)": "{:,.2f}",
        },
        height=320,
    )
