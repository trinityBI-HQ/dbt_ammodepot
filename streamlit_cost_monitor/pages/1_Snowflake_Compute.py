"""Page 1 — Snowflake compute spend (MTD + 90-day trend + breakdowns)."""

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from utils.chart_theme import ACCENT, WARNING, apply_theme, dark_dataframe, kpi_card
from utils.db import run_query
from utils.snowflake_queries import (
    cost_by_query_tag_mtd,
    cost_by_user_mtd,
    cost_by_warehouse_mtd,
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
    st.plotly_chart(fig, use_container_width=True, theme=None)

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
        st.plotly_chart(fig, use_container_width=True, theme=None)

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
        st.plotly_chart(fig, use_container_width=True, theme=None)

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
    st.plotly_chart(fig, use_container_width=True, theme=None)
