"""Forecast — Demand prediction and stock-out risk alerts.

Reads pre-computed predictions from F_FORECAST (populated daily by
TASK_DAILY_FORECAST at 4am UTC via SNOWFLAKE.ML.FORECAST).
Combines with F_INVENTORYVIEW (current stock) and F_POS (vendor lead times)
to calculate stock-out risk and reorder-by dates.

Source: AD_ANALYTICS.GOLD.F_FORECAST, F_INVENTORYVIEW, F_POS, INT_PRODUCT_ANALYST
"""

import base64
import pathlib

import pandas as pd
import plotly.graph_objects as go
import streamlit as st
from datetime import date

from utils.db import run_query
from utils.chart_theme import (
    apply_theme,
    dark_dataframe,
    BG_CHART,
    ACCENT,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
)

_logo_path = pathlib.Path(__file__).parents[1] / "AmmoDepot.png"
_logo_b64 = base64.b64encode(_logo_path.read_bytes()).decode()
if hasattr(st, "logo"):
    st.logo(str(_logo_path))

st.markdown(
    "<style>"
    "   .block-container {padding-left: 1rem; padding-right: 1rem; max-width: 100%;}"
    "   .stMainBlockContainer {max-width: 100%;}"
    "</style>",
    unsafe_allow_html=True,
)

st.markdown(
    f'<div style="display:flex;align-items:center;gap:12px;">'
    f'<img src="data:image/png;base64,{_logo_b64}" height="48">'
    f'<h1 style="margin:0;">DEMAND FORECAST</h1>'
    f'</div>',
    unsafe_allow_html=True,
)


# ── Data Loading ─────────────────────────────────────────────────────────────

@st.cache_data(ttl="10m", show_spinner=False)
def load_forecast() -> pd.DataFrame:
    return run_query("""
        SELECT CALIBER, FORECAST_DATE, PREDICTED_UNITS, LOWER_BOUND, UPPER_BOUND,
               FORECAST_TYPE, TRAINED_AT
        FROM F_FORECAST
        WHERE FORECAST_TYPE = 'caliber'
          AND FORECAST_DATE > CURRENT_DATE()
          AND FORECAST_DATE <= DATEADD('DAY', 30, CURRENT_DATE())
        ORDER BY CALIBER, FORECAST_DATE
    """)


@st.cache_data(ttl="10m", show_spinner=False)
def load_revenue_forecast() -> pd.DataFrame:
    return run_query("""
        SELECT FORECAST_DATE, PREDICTED_UNITS AS PREDICTED_REVENUE,
               LOWER_BOUND, UPPER_BOUND, TRAINED_AT
        FROM F_FORECAST
        WHERE FORECAST_TYPE = 'revenue'
          AND FORECAST_DATE > CURRENT_DATE()
          AND FORECAST_DATE <= DATEADD('DAY', 30, CURRENT_DATE())
        ORDER BY FORECAST_DATE
    """)


@st.cache_data(ttl="10m", show_spinner=False)
def load_actuals_30d() -> pd.DataFrame:
    return run_query("""
        SELECT s.CREATED_AT::DATE AS SALE_DATE, p.CALIBER,
               SUM(s.QTY_ORDERED) AS UNITS_SOLD
        FROM F_SALES s
        JOIN INT_PRODUCT_ANALYST p ON s.PRODUCT_ID = p.PRODUCT_ID
        WHERE s.CREATED_AT::DATE >= DATEADD('DAY', -30, CURRENT_DATE())
          AND s.STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
          AND p.CALIBER IS NOT NULL
        GROUP BY 1, 2
    """)


@st.cache_data(ttl="10m", show_spinner=False)
def load_revenue_actuals_30d() -> pd.DataFrame:
    return run_query("""
        SELECT CREATED_AT::DATE AS SALE_DATE,
               SUM(ROW_TOTAL) AS TOTAL_REVENUE
        FROM F_SALES
        WHERE CREATED_AT::DATE >= DATEADD('DAY', -30, CURRENT_DATE())
          AND STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
        GROUP BY 1
        ORDER BY 1
    """)


@st.cache_data(ttl="10m", show_spinner=False)
def load_stockout_risk() -> pd.DataFrame:
    return run_query("""
        WITH predicted_demand AS (
            SELECT CALIBER,
                   SUM(PREDICTED_UNITS) AS DEMAND_30D,
                   AVG(PREDICTED_UNITS) AS DAILY_AVG_PREDICTED
            FROM F_FORECAST
            WHERE FORECAST_TYPE = 'caliber'
              AND FORECAST_DATE > CURRENT_DATE()
              AND FORECAST_DATE <= DATEADD('DAY', 30, CURRENT_DATE())
            GROUP BY CALIBER
        ),
        current_stock AS (
            SELECT p.CALIBER,
                   SUM(i.QTY_AVAILABLE)   AS QTY_ON_HAND,
                   SUM(i.QTY_ON_ORDER)    AS QTY_ON_ORDER,
                   SUM(i.EXTENDED_COST)   AS INVENTORY_VALUE
            FROM F_INVENTORYVIEW i
            JOIN INT_PRODUCT_ANALYST p ON i.PART_NUMBER = p.SKU
            WHERE p.CALIBER IS NOT NULL
            GROUP BY p.CALIBER
        ),
        lead_times AS (
            SELECT p.CALIBER,
                   ROUND(AVG(po.PRECISE_LEADTIME), 0) AS AVG_LEAD_TIME_DAYS
            FROM F_POS po
            JOIN INT_PRODUCT_ANALYST p ON po.PART_NUMBER = p.SKU
            WHERE po.PRECISE_LEADTIME IS NOT NULL
              AND p.CALIBER IS NOT NULL
            GROUP BY p.CALIBER
        )
        SELECT
            cs.CALIBER,
            cs.QTY_ON_HAND,
            cs.QTY_ON_ORDER,
            ROUND(cs.INVENTORY_VALUE, 2) AS INVENTORY_VALUE,
            ROUND(pd.DEMAND_30D, 0) AS DEMAND_30D,
            ROUND(pd.DAILY_AVG_PREDICTED, 1) AS DAILY_AVG_PREDICTED,
            CASE WHEN pd.DAILY_AVG_PREDICTED > 0
                 THEN ROUND(cs.QTY_ON_HAND / pd.DAILY_AVG_PREDICTED, 1)
                 ELSE NULL END AS DAYS_OF_SUPPLY,
            COALESCE(lt.AVG_LEAD_TIME_DAYS, 14) AS LEAD_TIME_DAYS,
            CASE WHEN pd.DAILY_AVG_PREDICTED > 0
                 THEN DATEADD('DAY',
                    GREATEST(ROUND(cs.QTY_ON_HAND / pd.DAILY_AVG_PREDICTED) - COALESCE(lt.AVG_LEAD_TIME_DAYS, 14), 0)::INT,
                    CURRENT_DATE())
                 ELSE NULL END AS REORDER_BY,
            CASE
                WHEN pd.DAILY_AVG_PREDICTED > 0
                     AND cs.QTY_ON_HAND / pd.DAILY_AVG_PREDICTED <= COALESCE(lt.AVG_LEAD_TIME_DAYS, 14)
                THEN 'Critical'
                WHEN pd.DAILY_AVG_PREDICTED > 0
                     AND cs.QTY_ON_HAND / pd.DAILY_AVG_PREDICTED <= COALESCE(lt.AVG_LEAD_TIME_DAYS, 14) * 2
                THEN 'Warning'
                WHEN pd.DAILY_AVG_PREDICTED > 0
                     AND cs.QTY_ON_HAND / pd.DAILY_AVG_PREDICTED > 90
                THEN 'Overstock'
                ELSE 'OK'
            END AS RISK_LEVEL
        FROM current_stock cs
        LEFT JOIN predicted_demand pd ON cs.CALIBER = pd.CALIBER
        LEFT JOIN lead_times lt ON cs.CALIBER = lt.CALIBER
        WHERE cs.QTY_ON_HAND > 0
        ORDER BY DAYS_OF_SUPPLY ASC NULLS LAST
    """)


# ── Check if forecast data exists ────────────────────────────────────────────

fc_data = load_forecast()
if fc_data.empty:
    st.warning(
        "Forecast data not yet available. The training task runs daily at 4am UTC. "
        "To populate manually, run: `CALL AD_ANALYTICS.GOLD.SP_TRAIN_FORECAST();`"
    )
    st.stop()

trained_at = fc_data["TRAINED_AT"].max()
st.caption(f"Last trained: {trained_at}")

# ── Tabs ─────────────────────────────────────────────────────────────────────

tab_risk, tab_caliber, tab_revenue = st.tabs(
    ["Stock-Out Risk", "Caliber Forecast", "Revenue Forecast"]
)

# ── Tab 1: Stock-Out Risk ────────────────────────────────────────────────────

with tab_risk:
    risk = load_stockout_risk()

    if risk.empty:
        st.info("No stock-out risk data available.")
    else:
        critical = risk[risk["RISK_LEVEL"] == "Critical"]
        warning = risk[risk["RISK_LEVEL"] == "Warning"]
        ok = risk[risk["RISK_LEVEL"] == "OK"]
        overstock = risk[risk["RISK_LEVEL"] == "Overstock"]

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Critical", len(critical))
        c2.metric("Warning", len(warning))
        c3.metric("OK", len(ok))
        c4.metric("Overstock", len(overstock))

        risk_filter = st.selectbox(
            "Filter by risk level",
            ["All", "Critical", "Warning", "OK", "Overstock"],
            index=0,
        )

        display_df = risk if risk_filter == "All" else risk[risk["RISK_LEVEL"] == risk_filter]
        dark_dataframe(display_df)

# ── Tab 2: Caliber Forecast Chart ────────────────────────────────────────────

with tab_caliber:
    calibers = sorted(fc_data["CALIBER"].dropna().unique().tolist())
    selected = st.selectbox("Select caliber", calibers, index=0, key="fc_caliber")

    if selected:
        fc_cal = fc_data[fc_data["CALIBER"] == selected].copy()
        actuals = load_actuals_30d()
        act_cal = (
            actuals[actuals["CALIBER"] == selected]
            .groupby("SALE_DATE")["UNITS_SOLD"]
            .sum()
            .reset_index()
        )

        fig = go.Figure()

        if not act_cal.empty:
            fig.add_trace(
                go.Scatter(
                    x=act_cal["SALE_DATE"].tolist(),
                    y=[float(v) for v in act_cal["UNITS_SOLD"].tolist()],
                    mode="lines+markers",
                    name="Actual (last 30d)",
                    line=dict(color=ACCENT, width=2),
                    marker=dict(size=4),
                )
            )

        if not fc_cal.empty:
            fig.add_trace(
                go.Scatter(
                    x=fc_cal["FORECAST_DATE"].tolist(),
                    y=[float(v) for v in fc_cal["PREDICTED_UNITS"].tolist()],
                    mode="lines",
                    name="Forecast (next 30d)",
                    line=dict(color="#FFD700", width=2, dash="dash"),
                )
            )
            fig.add_trace(
                go.Scatter(
                    x=fc_cal["FORECAST_DATE"].tolist(),
                    y=[float(v) for v in fc_cal["UPPER_BOUND"].tolist()],
                    mode="lines",
                    name="Upper bound",
                    line=dict(color="rgba(255,215,0,0.2)", width=0),
                    showlegend=False,
                )
            )
            fig.add_trace(
                go.Scatter(
                    x=fc_cal["FORECAST_DATE"].tolist(),
                    y=[float(v) for v in fc_cal["LOWER_BOUND"].tolist()],
                    mode="lines",
                    name="Confidence band",
                    line=dict(color="rgba(255,215,0,0.2)", width=0),
                    fill="tonexty",
                    fillcolor="rgba(255,215,0,0.1)",
                )
            )

        apply_theme(fig)
        fig.update_layout(
            title="",
            xaxis_title="Date",
            yaxis_title="Units",
            legend=dict(orientation="h", yanchor="bottom", y=1.0, xanchor="left", x=0),
            margin=dict(t=40),
        )
        st.subheader(f"{selected} — Daily Units Sold (Actual + Forecast)")
        st.plotly_chart(fig, use_container_width=True, key=f"fc_chart_{selected}")

        st.subheader("Forecast Data")
        dark_dataframe(fc_cal[["FORECAST_DATE", "PREDICTED_UNITS", "LOWER_BOUND", "UPPER_BOUND"]])

# ── Tab 3: Revenue Forecast ──────────────────────────────────────────────────

with tab_revenue:
    rev_fc = load_revenue_forecast()
    rev_act = load_revenue_actuals_30d()

    if rev_fc.empty:
        st.info("Revenue forecast not yet available.")
    else:
        fig_rev = go.Figure()

        if not rev_act.empty:
            fig_rev.add_trace(
                go.Scatter(
                    x=rev_act["SALE_DATE"].tolist(),
                    y=[float(v) for v in rev_act["TOTAL_REVENUE"].tolist()],
                    mode="lines+markers",
                    name="Actual (last 30d)",
                    line=dict(color=ACCENT, width=2),
                    marker=dict(size=4),
                )
            )

        fig_rev.add_trace(
            go.Scatter(
                x=rev_fc["FORECAST_DATE"].tolist(),
                y=[float(v) for v in rev_fc["PREDICTED_REVENUE"].tolist()],
                mode="lines",
                name="Forecast (next 30d)",
                line=dict(color="#FFD700", width=2, dash="dash"),
            )
        )

        apply_theme(fig_rev)
        fig_rev.update_layout(
            title="",
            xaxis_title="Date",
            yaxis_title="Revenue ($)",
            legend=dict(orientation="h", yanchor="bottom", y=1.0, xanchor="left", x=0),
            margin=dict(t=40),
        )
        st.subheader("Daily Revenue — Actual + Forecast")
        st.plotly_chart(fig_rev, use_container_width=True, key="rev_fc_chart")

        total_predicted = sum(float(v) for v in rev_fc["PREDICTED_REVENUE"].tolist())
        st.metric("Predicted Revenue (Next 30 Days)", f"${total_predicted:,.0f}")
