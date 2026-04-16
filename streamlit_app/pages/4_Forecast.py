"""Forecast — Demand prediction, stock-out risk, and reorder intelligence.

Reads pre-computed predictions from F_FORECAST (populated weekly by
TASK_DAILY_FORECAST at 4am UTC via SNOWFLAKE.ML.FORECAST).
Combines with F_INVENTORYVIEW (current stock) and F_POS (vendor lead times)
to calculate stock-out risk and reorder-by dates.

AI Roadmap Phase 5: Reorder Recommendations tab reads F_REORDER_RECOMMENDATIONS
(pre-computed Gold table) and generates a CORTEX.COMPLETE purchasing brief.

Source: AD_ANALYTICS.GOLD.F_FORECAST, F_INVENTORYVIEW, F_POS,
        INT_PRODUCT_ANALYST, F_REORDER_RECOMMENDATIONS
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


# ── Reorder Intelligence ─────────────────────────────────────────────────────

@st.cache_data(ttl=3600, show_spinner=False)
def load_caliber_evaluate() -> pd.DataFrame:
    """Run CALIBER_FORECAST!EVALUATE() — cross-validated backtesting metrics per caliber."""
    try:
        return run_query("""
            select *
            from table(ad_analytics.gold.caliber_forecast!evaluate())
            order by mape asc nulls last
        """)
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl="10m", show_spinner=False)
def load_forecast_vs_actual(lookback_days: int = 30) -> pd.DataFrame:
    """Compare archived forecasts to actuals once F_FORECAST_HISTORY accumulates data."""
    try:
        return run_query(f"""
            with actuals as (
                select
                    created_at::date          as sale_date,
                    p.caliber,
                    sum(qty_ordered)          as actual_units
                from f_sales s
                join int_product_analyst p on s.product_id = p.product_id
                where s.status in ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
                  and p.caliber is not null
                  and created_at >= dateadd('day', -{lookback_days}, current_date())
                group by 1, 2
            ),
            predictions as (
                select
                    forecast_date,
                    caliber,
                    predicted_units,
                    lower_bound,
                    upper_bound,
                    archived_at::date as run_date
                from ad_analytics.gold.f_forecast_history
                where forecast_type = 'caliber'
                qualify row_number() over (
                    partition by caliber, forecast_date
                    order by archived_at asc
                ) = 1
            )
            select
                a.caliber,
                count(*)                                                    as matched_days,
                round(avg(abs(a.actual_units - p.predicted_units)), 1)      as mae,
                round(avg(abs(a.actual_units - p.predicted_units)
                          / nullif(a.actual_units, 0)) * 100, 1)            as mape,
                round(avg(a.actual_units - p.predicted_units), 1)           as bias,
                sum(case when a.actual_units between p.lower_bound
                                                 and p.upper_bound
                    then 1 else 0 end)                                      as within_band,
                round(within_band / count(*) * 100, 1)                     as coverage_pct
            from actuals a
            join predictions p
              on a.caliber = p.caliber
             and a.sale_date = p.forecast_date
            group by a.caliber
            having matched_days >= 7
            order by mape asc nulls last
        """)
    except Exception:
        return pd.DataFrame()


LLM_MODEL_REORDER = "gemini-2-5-flash"
LLM_CACHE_TTL_REORDER = 600  # seconds — matches dbt build cadence


@st.cache_data(ttl="10m", show_spinner=False)
def load_reorder_recommendations() -> pd.DataFrame:
    """Load pre-computed reorder recommendations from Gold table."""
    try:
        return run_query("""
            select
                caliber, qty_available, qty_on_order,
                demand_upper_30d, daily_avg_predicted,
                reorder_qty, lead_time_days, days_of_supply,
                reorder_by, urgency,
                recommended_vendor, avg_unit_cost, estimated_order_cost,
                refreshed_at
            from f_reorder_recommendations
            order by
                case urgency
                    when 'Critical'  then 1
                    when 'Warning'   then 2
                    when 'OK'        then 3
                    when 'Overstock' then 4
                    else 5
                end,
                days_of_supply asc nulls last
        """)
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl="10m", show_spinner=False)
def load_vendor_comparison(caliber: str) -> pd.DataFrame:
    """Top 5 vendors for a caliber ranked by avg lead time from PO history."""
    safe_caliber = caliber.replace("'", "''")
    try:
        return run_query(f"""
            select
                dv.vendor_name                              as VENDOR_NAME,
                round(avg(po.precise_leadtime), 0)          as AVG_LEAD_TIME_DAYS,
                round(avg(po.unit_cost), 3)                 as AVG_UNIT_COST,
                count(distinct po.purchase_order_id)        as HISTORICAL_POS,
                max(po.datereceived)                        as LAST_SUPPLIED
            from f_pos as po
            join int_product_analyst as p on po.part_number = p.sku
            join d_vendor as dv on po.vendor_id = dv.vendor_id
            where p.caliber = '{safe_caliber}'
              and po.precise_leadtime is not null
              and po.vendor_id is not null
            group by dv.vendor_name
            order by avg_lead_time_days asc nulls last
            limit 5
        """)
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl=LLM_CACHE_TTL_REORDER, show_spinner=False)
def generate_reorder_summary(reorder_json: str) -> str | None:
    """CORTEX.COMPLETE purchasing brief for top urgent calibers.

    Returns None on any failure — caller renders fallback caption.
    """
    try:
        prompt = (
            "You are a data analyst writing a 3-4 sentence purchasing brief "
            "for an ammunition retailer's operations manager. "
            "Be direct and numbers-forward — no filler, no greetings. "
            "Focus on Critical calibers: name the caliber, units to order, "
            "recommended vendor, and days of supply remaining. "
            "Mention the total estimated order cost at the end.\n\n"
            f"Reorder data (Critical and Warning calibers):\n{reorder_json}"
        )
        safe_prompt = prompt.replace("'", "''")
        df = run_query(f"""
            select snowflake.cortex.complete(
                '{LLM_MODEL_REORDER}',
                '{safe_prompt}'
            ) as summary
        """)
        if not df.empty and df.iloc[0]["SUMMARY"]:
            raw = str(df.iloc[0]["SUMMARY"]).strip()
            if raw.startswith('"') and raw.endswith('"'):
                raw = raw[1:-1]
            return raw
        return None
    except Exception:
        return None


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

tab_risk, tab_caliber, tab_revenue, tab_reorder, tab_accuracy = st.tabs(
    ["Stock-Out Risk", "Caliber Forecast", "Revenue Forecast",
     "Reorder Recommendations", "Forecast Accuracy"]
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

# ── Tab 4: Reorder Recommendations ──────────────────────────────────────────

with tab_reorder:
    reorder = load_reorder_recommendations()

    if reorder.empty:
        st.info(
            "Reorder recommendations not yet available. "
            "The Gold table populates on the next dbt build (within 10 min)."
        )
    else:
        urgent = reorder[reorder["URGENCY"].isin(["Critical", "Warning"])]
        reorder_json = urgent.head(10).to_json(orient="records")
        summary = generate_reorder_summary(reorder_json)

        if summary:
            st.markdown(
                f'<div style="background:#1a2733; border-left:4px solid {ACCENT}; '
                f'border-radius:8px; padding:16px 20px; margin-bottom:16px; '
                f'color:{TEXT_PRIMARY}; font-size:14px; line-height:1.6;">'
                f"{summary}</div>",
                unsafe_allow_html=True,
            )
        else:
            st.caption("Purchasing summary unavailable.")

        critical_count = int((reorder["URGENCY"] == "Critical").sum())
        ok_count = int((reorder["URGENCY"] == "OK").sum())
        total_cost = float(
            reorder.loc[reorder["REORDER_QTY"] > 0, "ESTIMATED_ORDER_COST"].sum()
        )

        k1, k2, k3 = st.columns(3)
        k1.metric("Critical Calibers", critical_count)
        k2.metric("Est. Order Cost", f"${total_cost:,.0f}")
        k3.metric("OK / Healthy", ok_count)

        urgency_filter = st.selectbox(
            "Filter by urgency",
            ["All", "Critical", "Warning", "OK", "Overstock"],
            index=0,
            key="reorder_urgency_filter",
        )
        display = (
            reorder if urgency_filter == "All"
            else reorder[reorder["URGENCY"] == urgency_filter]
        )

        dark_dataframe(
            display[[
                "CALIBER", "URGENCY", "REORDER_QTY", "DAYS_OF_SUPPLY",
                "LEAD_TIME_DAYS", "REORDER_BY", "RECOMMENDED_VENDOR",
                "AVG_UNIT_COST", "ESTIMATED_ORDER_COST",
            ]],
            fmt={
                "REORDER_QTY":          "{:,.0f}",
                "DAYS_OF_SUPPLY":       "{:,.1f}",
                "LEAD_TIME_DAYS":       "{:,.0f}",
                "AVG_UNIT_COST":        "${:,.3f}",
                "ESTIMATED_ORDER_COST": "${:,.0f}",
            },
        )

        # ── Vendor Comparison ─────────────────────────────────────────────────
        st.divider()
        st.subheader("Vendor Comparison")

        actionable = reorder.loc[
            reorder["URGENCY"].isin(["Critical", "Warning"])
            & (reorder["REORDER_QTY"] > 0)
        ].reset_index(drop=True)

        if actionable.empty:
            st.info("No calibers require reordering at this time.")
        else:
            caliber_labels = [
                f"{row.CALIBER}  ({row.URGENCY} · {int(row.REORDER_QTY):,} units)"
                for row in actionable.itertuples()
            ]
            selected_idx = st.selectbox(
                "Select caliber to compare vendors",
                range(len(caliber_labels)),
                format_func=lambda i: caliber_labels[i],
                key="vendor_compare_caliber",
            )
            selected_caliber = actionable.iloc[selected_idx]["CALIBER"]
            selected_reorder_qty = float(actionable.iloc[selected_idx]["REORDER_QTY"])

            vendor_df = load_vendor_comparison(selected_caliber)
            if vendor_df.empty:
                st.info(f"No vendor history found for {selected_caliber}.")
            else:
                vendor_df = vendor_df.copy()
                vendor_df["EST_ORDER_COST"] = vendor_df["AVG_UNIT_COST"].apply(
                    lambda c: round(selected_reorder_qty * float(c), 0)
                    if c is not None else None
                )
                dark_dataframe(
                    vendor_df[[
                        "VENDOR_NAME", "AVG_LEAD_TIME_DAYS", "AVG_UNIT_COST",
                        "EST_ORDER_COST", "HISTORICAL_POS", "LAST_SUPPLIED",
                    ]],
                    fmt={
                        "AVG_LEAD_TIME_DAYS": "{:,.0f}",
                        "AVG_UNIT_COST":      "${:,.3f}",
                        "EST_ORDER_COST":     "${:,.0f}",
                        "HISTORICAL_POS":     "{:,.0f}",
                    },
                )

# ── Tab 5: Forecast Accuracy ──────────────────────────────────────────────────

with tab_accuracy:
    st.subheader("Model Backtesting (EVALUATE)")
    st.caption(
        "Cross-validated metrics computed from the model's training data. "
        "MAPE = Mean Absolute % Error — lower is better. "
        "Updated weekly when the model retrains."
    )

    with st.spinner("Running model evaluation..."):
        eval_df = load_caliber_evaluate()

    if eval_df.empty:
        st.info("Evaluation not available. The CALIBER_FORECAST model may not be trained yet.")
    else:
        eval_cols = [c for c in ["SERIES", "MAPE", "MAE", "RMSE", "WMAPE", "COVERAGE"] if c in eval_df.columns]
        if eval_cols:
            col_a, col_b, col_c = st.columns(3)
            mape_vals = eval_df["MAPE"].dropna() if "MAPE" in eval_df.columns else None
            if mape_vals is not None and not mape_vals.empty:
                col_a.metric("Median MAPE", f"{float(mape_vals.median()):.1f}%")
                col_b.metric("Best Caliber MAPE", f"{float(mape_vals.min()):.1f}%")
                col_c.metric("Worst Caliber MAPE", f"{float(mape_vals.max()):.1f}%")

            dark_dataframe(
                eval_df[eval_cols],
                fmt={k: "{:,.1f}" for k in ["MAPE", "MAE", "RMSE", "WMAPE", "COVERAGE"]
                     if k in eval_cols},
            )

            if "MAPE" in eval_df.columns and "SERIES" in eval_df.columns:
                top20 = eval_df.dropna(subset=["MAPE"]).head(20)
                fig_mape = go.Figure(go.Bar(
                    x=top20["SERIES"].tolist(),
                    y=[float(v) for v in top20["MAPE"].tolist()],
                    marker_color=ACCENT,
                    text=[f"{float(v):.1f}%" for v in top20["MAPE"].tolist()],
                    textposition="outside",
                    textfont=dict(color=TEXT_PRIMARY, size=10),
                ))
                apply_theme(fig_mape, height=300, show_legend=False,
                            margin=dict(l=0, r=0, t=30, b=0))
                fig_mape.update_layout(
                    title="Top 20 Calibers by MAPE (best → worst)",
                    yaxis_title="MAPE %",
                    xaxis=dict(tickangle=-45),
                )
                st.plotly_chart(fig_mape, use_container_width=True, key="mape_chart")

    st.divider()
    st.subheader("Prediction vs Actual (Historical)")
    st.caption(
        "Compares archived forecast predictions to actual sales. "
        "Requires F_FORECAST_HISTORY — populates after the next weekly training run (Sunday 4am UTC)."
    )

    hist_df = load_forecast_vs_actual()
    if hist_df.empty:
        st.info(
            "No historical comparison data yet. "
            "F_FORECAST_HISTORY will be populated on the next weekly training run. "
            "Check back after Sunday 4am UTC."
        )
    else:
        h1, h2, h3, h4 = st.columns(4)
        if not hist_df.empty:
            h1.metric("Calibers tracked", len(hist_df))
            if "MAPE" in hist_df.columns:
                h2.metric("Median MAPE", f"{float(hist_df['MAPE'].median()):.1f}%")
            if "BIAS" in hist_df.columns:
                h3.metric("Avg Bias", f"{float(hist_df['BIAS'].mean()):+.0f} units/day")
            if "COVERAGE_PCT" in hist_df.columns:
                h4.metric("CI Coverage", f"{float(hist_df['COVERAGE_PCT'].mean()):.0f}%")

        dark_dataframe(
            hist_df,
            fmt={
                "MAE":          "{:,.1f}",
                "MAPE":         "{:,.1f}",
                "BIAS":         "{:+,.1f}",
                "COVERAGE_PCT": "{:,.0f}",
                "MATCHED_DAYS": "{:,.0f}",
                "WITHIN_BAND":  "{:,.0f}",
            },
        )
