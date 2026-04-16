"""Customer Intelligence — Segment health and churn risk.

AI Roadmap Phase 4: CORTEX.COMPLETE executive summary + RFM segment dashboard.
Source: AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION
"""

import base64
import pathlib

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

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

# ── Page Config ──────────────────────────────────────────────────────────────

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
    f'<h1 style="margin:0;">CUSTOMER INTELLIGENCE</h1>'
    f'</div>',
    unsafe_allow_html=True,
)

# ── Constants ────────────────────────────────────────────────────────────────

LLM_MODEL = "gemini-2-5-flash"
LLM_CACHE_TTL = 600  # seconds — matches dbt build cadence

CONCERNING_SEGMENTS = {
    "At-Risk Regular",
    "Lost Buyer",
    "Inactive",
    "Inactive Regular",
    "Lapsed Buyer",
    "Losing 1-Time Buyer",
}
POSITIVE_SEGMENTS = {
    "Super Engaged",
    "Highly Engaged",
    "Active Loyalist",
    "Engaged Regular",
    "New Buyer",
    "New Active Buyer",
}


# ── Data Loading ─────────────────────────────────────────────────────────────


@st.cache_data(ttl="10m", show_spinner=False)
def load_segment_summary() -> pd.DataFrame:
    """Aggregate D_CUSTOMER_SEGMENTATION by classification."""
    return run_query("""
        select
            customer_classification,
            count(*)                                    as customer_count,
            coalesce(sum(total_revenue), 0)             as total_ltv,
            coalesce(round(avg(days_since_last_purchase), 0), 0)
                                                        as avg_days_silent,
            coalesce(round(avg(number_of_purchases), 1), 0)
                                                        as avg_purchases
        from d_customer_segmentation
        group by customer_classification
        order by customer_count desc
    """)




@st.cache_data(ttl="10m", show_spinner=False)
def load_segment_prior(days: int = 30) -> pd.DataFrame:
    """Segment counts from snapshot ~N days ago. Returns empty df if no history yet."""
    try:
        return run_query(f"""
            select
                customer_classification,
                count(distinct rank_id) as prior_count
            from ad_analytics.gold.snap_customer_segmentation
            where dbt_valid_from <= dateadd('day', -{days}, current_date())
              and (dbt_valid_to > dateadd('day', -{days}, current_date())
                   or dbt_valid_to is null)
            group by customer_classification
        """)
    except Exception:
        return pd.DataFrame()


@st.cache_data(ttl="10m", show_spinner=False)
def load_top_at_risk(n: int = 10) -> pd.DataFrame:
    """Top N highest-value customers in concerning segments."""
    segments_sql = ", ".join(f"'{s}'" for s in CONCERNING_SEGMENTS)
    return run_query(f"""
        select
            rank_id,
            customer_classification,
            total_revenue,
            days_since_last_purchase,
            number_of_purchases,
            total_purchases_all_time,
            frequency,
            recency,
            customer_group
        from d_customer_segmentation
        where customer_classification in ({segments_sql})
          and total_revenue is not null
        order by total_revenue desc
        limit {n}
    """)


# ── LLM Executive Summary ───────────────────────────────────────────────────


@st.cache_data(ttl=LLM_CACHE_TTL, show_spinner=False)
def generate_executive_summary(segment_json: str) -> str | None:
    """Call CORTEX.COMPLETE to generate executive summary.

    Returns None on any failure — caller renders fallback.
    """
    try:
        prompt = (
            "You are a data analyst writing a 3-4 sentence executive summary "
            "for operations managers at an ammunition retailer. "
            "Be numbers-forward and concise — no filler, no greetings, no caveats. "
            "Highlight concerning trends (growing at-risk segments, high-value "
            "customers going silent). "
            "Reference specific segment names and numbers from the data.\n\n"
            f"Customer segment data:\n{segment_json}"
        )
        safe_prompt = prompt.replace("'", "''")
        df = run_query(f"""
            select snowflake.cortex.complete(
                '{LLM_MODEL}',
                '{safe_prompt}'
            ) as summary
        """)
        if not df.empty and df.iloc[0]["SUMMARY"]:
            raw = str(df.iloc[0]["SUMMARY"]).strip()
            # Some models wrap the response in quotes — strip them
            if raw.startswith('"') and raw.endswith('"'):
                raw = raw[1:-1]
            return raw
        return None
    except Exception:
        return None


# ── Render Functions ─────────────────────────────────────────────────────────


def render_summary_banner(summary: str | None):
    """Render the LLM executive summary as a styled banner."""
    if summary:
        st.markdown(
            f'<div style="background:#1a2733; border-left:4px solid {ACCENT}; '
            f'border-radius:8px; padding:16px 20px; margin-bottom:16px; '
            f'color:{TEXT_PRIMARY}; font-size:14px; line-height:1.6;">'
            f"{summary}</div>",
            unsafe_allow_html=True,
        )
    else:
        st.caption("Executive summary unavailable.")


def render_kpi_cards(df_segments: pd.DataFrame):
    """Render 4 KPI cards from segment summary data."""
    total_customers = int(df_segments["CUSTOMER_COUNT"].sum())
    at_risk_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"].isin(CONCERNING_SEGMENTS),
            "CUSTOMER_COUNT",
        ].sum()
    )
    lost_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"] == "Lost Buyer",
            "CUSTOMER_COUNT",
        ].sum()
    )
    positive_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"].isin(POSITIVE_SEGMENTS),
            "CUSTOMER_COUNT",
        ].sum()
    )
    health_pct = (positive_count / total_customers * 100) if total_customers else 0

    at_risk_pct = (at_risk_count / total_customers * 100) if total_customers else 0
    lost_ltv = df_segments.loc[
        df_segments["CUSTOMER_CLASSIFICATION"] == "Lost Buyer", "TOTAL_LTV"
    ]
    lost_ltv_val = float(lost_ltv.sum()) if not lost_ltv.empty else 0
    positive_ltv = df_segments.loc[
        df_segments["CUSTOMER_CLASSIFICATION"].isin(POSITIVE_SEGMENTS), "TOTAL_LTV"
    ]
    positive_ltv_val = float(positive_ltv.sum()) if not positive_ltv.empty else 0

    cards = [
        {
            "icon": "&#x1F465;",
            "color": "#00B4D8",
            "title": "Total Customers",
            "value": f"{total_customers:,}",
            "sub_label": "With purchases in L12M",
            "sub_value": f"{total_customers:,}",
        },
        {
            "icon": "&#x26A0;&#xFE0F;",
            "color": "#FF4B4B",
            "title": "At-Risk",
            "value": f"{at_risk_count:,}",
            "sub_label": "% of Total",
            "sub_value": f"{at_risk_pct:.1f}%",
        },
        {
            "icon": "&#x1F6AB;",
            "color": "#FF4B4B",
            "title": "Lost Buyers",
            "value": f"{lost_count:,}",
            "sub_label": "LTV at Risk",
            "sub_value": f"${lost_ltv_val:,.0f}",
        },
        {
            "icon": "&#x2705;",
            "color": "#2DC653",
            "title": "Healthy Segments",
            "value": f"{health_pct:.1f}%",
            "sub_label": "Healthy LTV",
            "sub_value": f"${positive_ltv_val:,.0f}",
        },
    ]

    st.markdown(
        """
        <style>
        .kpi-card {
            background: #1E1E1E;
            border-radius: 8px;
            padding: 12px 16px;
            border-left: 4px solid;
            height: 100%;
        }
        .kpi-header {
            display: flex;
            align-items: center;
            gap: 6px;
            margin-bottom: 4px;
        }
        .kpi-icon { font-size: 18px; }
        .kpi-title {
            font-size: 12px;
            color: #AAAAAA;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .kpi-value {
            font-size: 24px;
            font-weight: 700;
            color: #FFFFFF;
            margin: 2px 0;
        }
        .kpi-sub {
            font-size: 11px;
            color: #888888;
            border-top: 1px solid #333;
            padding-top: 6px;
            margin-top: 4px;
        }
        .kpi-sub-val {
            color: #CCCCCC;
            font-weight: 600;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    kpi_cols = st.columns(4)
    for i, card in enumerate(cards):
        html = f"""
        <div class="kpi-card" style="border-left-color: {card['color']};">
            <div class="kpi-header">
                <span class="kpi-icon">{card['icon']}</span>
                <span class="kpi-title">{card['title']}</span>
            </div>
            <div class="kpi-value">{card['value']}</div>
            <div class="kpi-sub">
                {card['sub_label']}: <span class="kpi-sub-val">{card['sub_value']}</span>
            </div>
        </div>
        """
        with kpi_cols[i]:
            st.markdown(html, unsafe_allow_html=True)


def render_segment_table(df_segments: pd.DataFrame, df_prior: pd.DataFrame):
    """Render segment health table with MoM delta column when prior data exists."""
    display = df_segments[
        ["CUSTOMER_CLASSIFICATION", "CUSTOMER_COUNT", "TOTAL_LTV",
         "AVG_DAYS_SILENT", "AVG_PURCHASES"]
    ].copy()
    display.columns = ["Segment", "Customers", "Total LTV", "Avg Days Silent", "Avg Purchases"]

    if not df_prior.empty:
        prior_map = df_prior.set_index("CUSTOMER_CLASSIFICATION")["PRIOR_COUNT"].to_dict()
        def _mom(row):
            prior = prior_map.get(row["Segment"])
            if prior is None:
                return "—"
            delta = int(row["Customers"]) - int(prior)
            return f"+{delta:,}" if delta > 0 else f"{delta:,}"
        display["MoM"] = display.apply(_mom, axis=1)

    dark_dataframe(
        display,
        fmt={
            "Customers": "{:,.0f}",
            "Total LTV": "${:,.0f}",
            "Avg Days Silent": "{:,.0f}",
            "Avg Purchases": "{:,.1f}",
        },
        height=500,
    )


def render_segment_chart(df_segments: pd.DataFrame):
    """Horizontal bar chart of customer count by segment."""
    df_sorted = df_segments.sort_values("CUSTOMER_COUNT", ascending=True)

    colors = [
        "#FF4B4B" if seg in CONCERNING_SEGMENTS
        else ACCENT if seg in POSITIVE_SEGMENTS
        else TEXT_SECONDARY
        for seg in df_sorted["CUSTOMER_CLASSIFICATION"]
    ]

    fig = go.Figure(
        go.Bar(
            x=df_sorted["CUSTOMER_COUNT"].tolist(),
            y=df_sorted["CUSTOMER_CLASSIFICATION"].tolist(),
            orientation="h",
            marker_color=colors,
            text=df_sorted["CUSTOMER_COUNT"].tolist(),
            textposition="outside",
            textfont=dict(color=TEXT_PRIMARY, size=11),
        )
    )
    apply_theme(fig, height=450, show_legend=False, margin=dict(l=0, r=40, t=10, b=0))
    fig.update_layout(
        xaxis_title="Customer Count",
        yaxis=dict(automargin=True),
    )
    st.plotly_chart(fig, use_container_width=True, key="seg_dist")


def render_at_risk_table(df_at_risk: pd.DataFrame):
    """Render top at-risk customers table with dark theme."""
    if df_at_risk.empty:
        st.info("No at-risk customers found.")
        return
    display = df_at_risk[
        ["RANK_ID", "CUSTOMER_CLASSIFICATION", "TOTAL_REVENUE",
         "DAYS_SINCE_LAST_PURCHASE", "NUMBER_OF_PURCHASES",
         "TOTAL_PURCHASES_ALL_TIME", "CUSTOMER_GROUP"]
    ].copy()
    display.columns = [
        "Customer ID", "Segment", "LTV (L12M)", "Days Silent",
        "Purchases (L12M)", "Purchases (All Time)", "Group",
    ]
    dark_dataframe(
        display,
        fmt={
            "LTV (L12M)": "${:,.0f}",
            "Days Silent": "{:,.0f}",
            "Purchases (L12M)": "{:,.0f}",
            "Purchases (All Time)": "{:,.0f}",
        },
    )




# ── Page Execution ───────────────────────────────────────────────────────────

# 1. Load data (all cached)
df_segments = load_segment_summary()
df_at_risk = load_top_at_risk()
df_prior = load_segment_prior()

if df_segments.empty:
    st.warning("No customer segmentation data available.")
    st.stop()

# 2. Generate LLM summary (cached, may return None)
segment_json = df_segments.to_json(orient="records")
summary = generate_executive_summary(segment_json)

# 3. Render (top-to-bottom)
render_summary_banner(summary)
st.divider()
render_kpi_cards(df_segments)
st.divider()

col_table, col_chart = st.columns([1, 1])
with col_table:
    st.subheader("Segment Health")
    if df_prior.empty:
        st.caption("MoM column will appear after 30 days of snapshot history.")
    render_segment_table(df_segments, df_prior)
with col_chart:
    st.subheader("Segment Distribution")
    render_segment_chart(df_segments)

st.divider()
st.subheader("Top At-Risk Customers (by Lifetime Value)")
render_at_risk_table(df_at_risk)

