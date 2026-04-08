"""Page 5 — Combined Snowflake + AWS monthly cost view."""

import streamlit as st

from utils.aws_costs import mtd_summary_aws
from utils.chart_theme import kpi_card
from utils.db import run_query
from utils.snowflake_queries import mtd_summary

st.set_page_config(page_title="Combined Cost", layout="wide")
st.title("Combined Pipeline Cost — Snowflake + AWS")
st.caption("Single source of truth for month-to-date pipeline spend.")

sf = run_query(mtd_summary()).iloc[0]
sf_mtd = float(sf["DOLLARS_MTD"] or 0)
sf_prior = float(sf["DOLLARS_PRIOR_MTD"] or 0)

try:
    aws = mtd_summary_aws()
    aws_mtd = float(aws["dollars_mtd"])
    aws_prior = float(aws["dollars_prior_mtd"])
    aws_ok = True
except Exception as exc:  # noqa: BLE001
    st.warning(
        "AWS data unavailable — showing Snowflake only. "
        "Fix the External Access Integration if you expect AWS numbers here."
    )
    st.exception(exc)
    aws_mtd = 0.0
    aws_prior = 0.0
    aws_ok = False

total_mtd = sf_mtd + aws_mtd
total_prior = sf_prior + aws_prior
delta = total_mtd - total_prior
delta_pct = (delta / total_prior * 100.0) if total_prior else None

k1, k2, k3, k4 = st.columns(4)
with k1:
    kpi_card("Total MTD", f"${total_mtd:,.0f}")
with k2:
    kpi_card("Snowflake", f"${sf_mtd:,.0f}")
with k3:
    kpi_card("AWS", f"${aws_mtd:,.0f}" if aws_ok else "—")
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

st.subheader("Split")
rows = [
    ("Snowflake compute", sf_mtd, sf_prior),
    ("AWS infrastructure", aws_mtd, aws_prior),
]

import pandas as pd  # noqa: E402
import plotly.graph_objects as go  # noqa: E402

from utils.chart_theme import ACCENT, WARNING, apply_theme  # noqa: E402

df = pd.DataFrame(rows, columns=["source", "mtd", "prior"])
fig = go.Figure()
fig.add_trace(
    go.Bar(
        x=df["source"].tolist(),
        y=df["mtd"].astype(float).tolist(),
        name="Current MTD",
        marker_color=ACCENT,
        text=[f"${v:,.0f}" for v in df["mtd"].astype(float)],
        textposition="outside",
    )
)
fig.add_trace(
    go.Bar(
        x=df["source"].tolist(),
        y=df["prior"].astype(float).tolist(),
        name="Prior Month (same day)",
        marker_color=WARNING,
        text=[f"${v:,.0f}" for v in df["prior"].astype(float)],
        textposition="outside",
    )
)
fig.update_layout(barmode="group")
fig.update_yaxes(tickprefix="$", tickformat=",.0f")
apply_theme(fig, height=360)
st.plotly_chart(fig, use_container_width=True, theme=None)

st.caption(
    "*Snowflake side uses `CREDIT_PRICE_USD` from `utils/config.py`. "
    "AWS side is unblended cost from Cost Explorer (excludes credits/refunds).*"
)
