"""Page 4 — AWS infrastructure cost via Cost Explorer."""

import plotly.graph_objects as go
import streamlit as st

from utils.aws_costs import (
    cost_by_service_mtd,
    daily_cost_by_service,
    mtd_summary_aws,
)
from utils.chart_theme import ACCENT, WARNING, apply_theme, dark_dataframe, kpi_card

st.set_page_config(page_title="AWS Infrastructure", layout="wide")
st.title("AWS Infrastructure")
st.caption(
    "Cost Explorer API (account 746669199691, us-east-1). "
    "Credentials loaded from the Snowflake secret via the External Access Integration."
)

# --------------------------------------------------------------------------- #
# KPI row
# --------------------------------------------------------------------------- #

try:
    summary = mtd_summary_aws()
except Exception as exc:  # noqa: BLE001
    st.error(
        "Unable to fetch AWS Cost Explorer data. Verify the External Access "
        "Integration + secret are attached to the Streamlit object."
    )
    st.exception(exc)
    st.stop()

mtd = float(summary["dollars_mtd"])
prior = float(summary["dollars_prior_mtd"])
delta = mtd - prior
delta_pct = summary["delta_pct"]

k1, k2, k3 = st.columns(3)
with k1:
    kpi_card("AWS Spend MTD", f"${mtd:,.2f}")
with k2:
    kpi_card("Prior Month (same day)", f"${prior:,.2f}")
with k3:
    if delta_pct is None:
        kpi_card("Delta", "—")
    else:
        arrow = "▲" if delta > 0 else "▼"
        kpi_card(
            "Delta",
            f"${abs(delta):,.2f}",
            delta=f"{arrow} {abs(delta_pct):.1f}%",
            delta_color="inverse",
        )

st.divider()

# --------------------------------------------------------------------------- #
# MTD breakdown by service
# --------------------------------------------------------------------------- #

st.subheader("MTD Cost by Service")
by_service = cost_by_service_mtd()
if by_service.empty:
    st.info("No AWS cost data MTD.")
else:
    show_all = st.checkbox(
        "Show all services (not just pipeline-relevant)",
        value=False,
        help=(
            "By default only services used by the analytics pipeline are shown. "
            "The relevant list is in `utils/config.py` (`AWS_RELEVANT_SERVICES`)."
        ),
    )
    filtered = by_service if show_all else by_service[by_service["relevant"]]
    if filtered.empty:
        st.info("No relevant services incurred cost this month.")
    else:
        fig = go.Figure(
            go.Bar(
                x=filtered["dollars"].astype(float).tolist(),
                y=filtered["service"].tolist(),
                orientation="h",
                marker_color=ACCENT,
                text=[f"${v:,.2f}" for v in filtered["dollars"].astype(float)],
                textposition="outside",
                hovertemplate="%{y}: $%{x:,.2f}<extra></extra>",
            )
        )
        fig.update_yaxes(autorange="reversed")
        fig.update_xaxes(tickprefix="$", tickformat=",.2f")
        apply_theme(fig, height=max(280, 28 * len(filtered)), show_legend=False)
        st.plotly_chart(fig, use_container_width=True, theme=None)

st.divider()

# --------------------------------------------------------------------------- #
# 90-day daily trend
# --------------------------------------------------------------------------- #

st.subheader("Daily Cost (90d)")
daily = daily_cost_by_service(days=90)
if daily.empty:
    st.info("No daily cost data.")
else:
    # Stack relevant services; roll everything else into "Other".
    daily["bucket"] = daily.apply(
        lambda r: r["service"] if r["relevant"] else "Other",
        axis=1,
    )
    pivot = (
        daily.groupby(["usage_date", "bucket"])["dollars"]
        .sum()
        .unstack(fill_value=0)
        .sort_index()
    )
    fig = go.Figure()
    for col in pivot.columns:
        fig.add_trace(
            go.Scatter(
                x=pivot.index.tolist(),
                y=pivot[col].tolist(),
                mode="lines",
                name=col,
                stackgroup="one",
                hovertemplate="%{x|%Y-%m-%d}<br>" + col + ": $%{y:,.2f}<extra></extra>",
            )
        )
    fig.update_yaxes(tickprefix="$", tickformat=",.2f")
    apply_theme(fig, height=380)
    st.plotly_chart(fig, use_container_width=True, theme=None)

st.caption(
    "*Cost Explorer API charges $0.01 per request — results are cached for 6 hours.*"
)
