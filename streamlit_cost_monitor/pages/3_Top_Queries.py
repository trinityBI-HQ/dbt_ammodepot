"""Page 3 — Top 15 most expensive queries (last 7 days, all warehouses)."""

import streamlit as st

from utils.chart_theme import dark_dataframe
from utils.db import run_query
from utils.snowflake_queries import cost_anomalies, top_expensive_queries

st.set_page_config(page_title="Top Queries", layout="wide")
st.title("Top Queries + Anomalies")

# --------------------------------------------------------------------------- #
# Anomaly detector
# --------------------------------------------------------------------------- #

st.subheader("Daily Cost Anomalies (30d window)")
st.caption(
    "Flagged when daily spend exceeds 2.5× the 28-day rolling median. "
    "Tune the multiplier in `utils/config.py`."
)

anomalies = run_query(cost_anomalies())
if anomalies.empty:
    st.info("No anomaly history yet (needs 28 days of data).")
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
            "MEDIAN_28D_CREDITS": "Median 28d (credits)",
            "STATUS": "Status",
        }
    )
    dark_dataframe(
        display,
        fmt={
            "Credits": "{:,.2f}",
            "Dollars": "${:,.2f}",
            "Median 28d (credits)": "{:,.2f}",
        },
        height=360,
    )

st.divider()

# --------------------------------------------------------------------------- #
# Top expensive queries
# --------------------------------------------------------------------------- #

st.subheader("Top 15 Expensive Queries (7d)")
st.caption(
    "Ranked by `max(total_elapsed_time)` across all warehouses. "
    "No hardcoded warehouse filter — fix #3 from the review."
)

queries = run_query(top_expensive_queries())
if queries.empty:
    st.info("No successful queries in the last 7 days.")
else:
    display = queries.rename(
        columns={
            "QUERY_PREVIEW": "Query",
            "WAREHOUSE_NAME": "Warehouse",
            "USER_NAME": "User",
            "ROLE_NAME": "Role",
            "QUERY_TAG": "Tag",
            "EXEC_SEC": "Exec (s)",
            "GB_SCANNED": "GB Scanned",
            "N_RUNS": "Runs",
        }
    )
    dark_dataframe(
        display,
        fmt={
            "Exec (s)": "{:,.1f}",
            "GB Scanned": "{:,.2f}",
            "Runs": "{:,.0f}",
        },
        height=480,
    )
