"""Page 2 — Snowflake storage (current snapshot + 30-day growth)."""

import plotly.graph_objects as go
import streamlit as st

from utils.chart_theme import apply_theme, dark_dataframe
from utils.db import run_query
from utils.snowflake_queries import (
    storage_current_snapshot,
    storage_growth_by_database,
)

st.set_page_config(page_title="Snowflake Storage", layout="wide")
st.title("Snowflake Storage")
st.caption(
    "Active + Failsafe storage per database. AD_AIRBYTE is the legacy "
    "ingest path (Failsafe retained; see CLAUDE.md). "
    "PC_FIVETRAN_DB is a candidate for drop."
)

snapshot = run_query(storage_current_snapshot())
if snapshot.empty:
    st.info("No storage data for yesterday.")
    st.stop()

# --------------------------------------------------------------------------- #
# Current snapshot
# --------------------------------------------------------------------------- #

st.subheader("Current (yesterday)")
snapshot_display = snapshot.rename(
    columns={
        "DATABASE_NAME": "Database",
        "ACTIVE_GB": "Active GB",
        "FAILSAFE_GB": "Failsafe GB",
        "TOTAL_GB": "Total GB",
    }
)
dark_dataframe(
    snapshot_display,
    fmt={
        "Active GB": "{:,.2f}",
        "Failsafe GB": "{:,.2f}",
        "Total GB": "{:,.2f}",
    },
)

st.divider()

# --------------------------------------------------------------------------- #
# 30-day growth trend
# --------------------------------------------------------------------------- #

st.subheader("30-Day Growth")
growth = run_query(storage_growth_by_database())
if growth.empty:
    st.info("No storage history available.")
    st.stop()

# Pivot active_gb by database, show as stacked area.
pivot = growth.pivot_table(
    index="USAGE_DATE", columns="DATABASE_NAME", values="ACTIVE_GB", aggfunc="sum"
).fillna(0)

fig = go.Figure()
for col in pivot.columns:
    fig.add_trace(
        go.Scatter(
            x=pivot.index.tolist(),
            y=pivot[col].tolist(),
            name=col,
            mode="lines",
            stackgroup="one",
            hovertemplate="%{x|%Y-%m-%d}<br>" + col + ": %{y:,.1f} GB<extra></extra>",
        )
    )
fig.update_yaxes(ticksuffix=" GB", tickformat=",.0f")
apply_theme(fig, height=360)
st.plotly_chart(fig, width="stretch", theme=None)

st.caption(
    "*Active only. Failsafe (Snowflake's 7-day disaster-recovery retention) "
    "is shown in the snapshot above — you pay for it but can't reclaim it early.*"
)
