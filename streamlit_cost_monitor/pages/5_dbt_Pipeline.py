"""Page 5 — dbt pipeline health: build duration, build history, and docs."""

import streamlit as st
import streamlit.components.v1 as components
import plotly.graph_objects as go

from utils.chart_theme import ACCENT, DANGER, TEXT_SECONDARY, apply_theme, dark_dataframe, kpi_card
from utils.cloudwatch_metrics import build_duration_timeseries, dbt_docs_presigned_url, recent_builds
from utils.config import CW_BUILD_CEILING_MIN, CW_METRIC_LOOKBACK_DAYS

st.set_page_config(page_title="dbt Pipeline", layout="wide")
st.title("dbt Pipeline")
st.caption(
    "Build duration from CloudWatch metric `AmmoDepot/dbt.BuildDurationMinutes`. "
    "Build health parsed from CloudWatch Logs `/ecs/ammodepot-dbt`."
)

# --------------------------------------------------------------------------- #
# KPI row
# --------------------------------------------------------------------------- #

try:
    builds = recent_builds()
except Exception as exc:  # noqa: BLE001
    st.error(
        "Unable to fetch CloudWatch data. Verify the IAM policy for "
        "`svc_snowflake_costs` includes CloudWatch + Logs read permissions, "
        "and the EAI allows egress to `monitoring.us-east-1.amazonaws.com` "
        "and `logs.us-east-1.amazonaws.com`."
    )
    st.exception(exc)
    st.stop()

if not builds.empty:
    last = builds.iloc[0]
    k1, k2, k3, k4 = st.columns(4)
    with k1:
        kpi_card("Last Build", str(last["Timestamp"]))
    with k2:
        status = str(last["Status"])
        kpi_card("Status", status)
    with k3:
        dur = last["Duration (min)"]
        kpi_card("Duration", f"{dur:.1f} min" if dur is not None else "—")
    with k4:
        if dur is not None:
            headroom = CW_BUILD_CEILING_MIN - dur
            kpi_card(
                "Headroom",
                f"{headroom:.1f} min",
                delta=f"{'OK' if headroom > 2 else 'tight'}" if headroom > 0 else "OVER",
                delta_color="normal" if headroom > 2 else "inverse",
            )
        else:
            kpi_card("Headroom", "—")

st.divider()

# --------------------------------------------------------------------------- #
# Build Duration chart (7d)
# --------------------------------------------------------------------------- #

st.subheader(f"Build Duration ({CW_METRIC_LOOKBACK_DAYS}d)")

try:
    df = build_duration_timeseries(days=CW_METRIC_LOOKBACK_DAYS)
except Exception as exc:  # noqa: BLE001
    st.error("Unable to fetch build duration metric from CloudWatch.")
    st.exception(exc)
    df = None

if df is not None and not df.empty:
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=df["timestamp"].tolist(),
            y=df["duration_min"].tolist(),
            mode="lines+markers",
            name="Build Duration",
            marker=dict(size=4),
            line=dict(color=ACCENT),
            hovertemplate="%{x|%b %d %H:%M}<br>%{y:.1f} min<extra></extra>",
        )
    )
    # 10-min ceiling reference line
    fig.add_hline(
        y=CW_BUILD_CEILING_MIN,
        line_dash="dash",
        line_color=DANGER,
        annotation_text=f"{CW_BUILD_CEILING_MIN:.0f}-min ceiling",
        annotation_position="top left",
        annotation_font_color=DANGER,
    )
    fig.update_yaxes(title_text="Minutes", rangemode="tozero")
    fig.update_xaxes(
        tickformat="%b %d",
        tickfont=dict(color=TEXT_SECONDARY, size=10),
    )
    apply_theme(fig, height=350)
    st.plotly_chart(fig, use_container_width=True, theme=None)
elif df is not None:
    st.info("No build duration data available in CloudWatch.")

st.divider()

# --------------------------------------------------------------------------- #
# Build health table
# --------------------------------------------------------------------------- #

st.subheader("Recent Builds")
if builds.empty:
    st.info("No build logs available in CloudWatch.")
else:
    dark_dataframe(builds, height=400)

st.divider()

# --------------------------------------------------------------------------- #
# dbt Docs iframe
# --------------------------------------------------------------------------- #

st.subheader("dbt Documentation")
st.caption("Interactive model lineage, descriptions, column types, and test definitions.")

docs_url = dbt_docs_presigned_url()
if docs_url:
    components.iframe(docs_url, height=700, scrolling=True)
else:
    st.info(
        "dbt docs not available. Ensure the CI workflow has deployed "
        "the static site to S3."
    )
