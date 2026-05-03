"""Page 6 — Airbyte Health: destination-freshness monitor for S3 Iceberg connections."""

import streamlit as st

from utils.chart_theme import BG_CHART, TEXT_PRIMARY, TEXT_SECONDARY, dark_dataframe
from utils.db import get_session
from utils.snowflake_queries import (
    get_airbyte_freshness,
    get_airbyte_freshness_per_stream,
)

st.set_page_config(page_title="Airbyte Health", layout="wide")
st.markdown(
    "<style>.block-container{padding-top:2rem;padding-left:2rem;"
    "padding-right:2rem;max-width:none}</style>",
    unsafe_allow_html=True,
)
st.title("Airbyte Health")
st.caption(
    "Destination-freshness monitor for the live S3 Iceberg ingestion path "
    "(Fishbowl → S3 and Magento → S3). Refreshes every 1 minute. "
    "Email alerts fire at WARN (30 min) and ALERT (60 min) thresholds via "
    "Snowflake ALERT objects."
)

# --------------------------------------------------------------------------- #
# Data
# --------------------------------------------------------------------------- #

session = get_session()

try:
    df_conn = get_airbyte_freshness(session)
except Exception as exc:  # noqa: BLE001
    st.error(
        "Unable to fetch Airbyte freshness data. Confirm that "
        "`AD_ANALYTICS.OPS.V_AIRBYTE_FRESHNESS` exists and that "
        "STREAMLIT_ROLE has SELECT on the view. "
        "Run setup/07_airbyte_observability.sql as ACCOUNTADMIN if needed."
    )
    st.exception(exc)
    st.stop()

try:
    df_streams = get_airbyte_freshness_per_stream(session)
except Exception as exc:  # noqa: BLE001
    st.error("Unable to fetch per-stream freshness data.")
    st.exception(exc)
    df_streams = None

# --------------------------------------------------------------------------- #
# KPI cards — one per connection, RAG colour-coded
# --------------------------------------------------------------------------- #

STATUS_COLOR = {
    "OK":    "#2ECC40",
    "WARN":  "#FFB000",
    "ALERT": "#FF4136",
}
STATUS_ICON = {
    "OK":    "OK",
    "WARN":  "WARN",
    "ALERT": "ALERT",
}

if df_conn.empty:
    st.warning(
        "No freshness data returned. The view may be empty if "
        "LAKEHOUSE_LANDING has no rows yet, or if the bootstrap SQL "
        "has not been run."
    )
else:
    cols = st.columns(max(len(df_conn), 1))
    for col, row in zip(cols, df_conn.itertuples(index=False)):
        color = STATUS_COLOR.get(str(row.status), "#999999")
        staleness_min = int(row.staleness_min) if row.staleness_min is not None else 0
        last_extract = str(row.newest_extracted_at) if row.newest_extracted_at is not None else "—"
        with col:
            st.markdown(
                f"""
                <div style="background:{BG_CHART};border-left:6px solid {color};
                            padding:1.2rem 1rem;border-radius:8px;margin-bottom:0.5rem;">
                  <div style="color:{TEXT_SECONDARY};font-size:0.85rem;
                              text-transform:uppercase;letter-spacing:0.06em;">
                    {row.connection_id}
                  </div>
                  <div style="color:{color};font-size:2.4rem;font-weight:700;
                              line-height:1.1;margin:0.3rem 0 0.6rem 0;">
                    {row.status}
                  </div>
                  <div style="color:{TEXT_PRIMARY};font-size:0.85rem;line-height:1.6;">
                    Oldest stream: <strong>{staleness_min} min stale</strong><br>
                    Tables monitored: {int(row.table_count)}<br>
                    Last extract: {last_extract}<br>
                    Thresholds: warn {int(row.warn_minutes)} / alert {int(row.alert_minutes)} min
                  </div>
                </div>
                """,
                unsafe_allow_html=True,
            )

st.divider()

# --------------------------------------------------------------------------- #
# Per-stream detail (collapsed by default to keep the page clean)
# --------------------------------------------------------------------------- #

st.subheader("Per-stream detail")

with st.expander("Show all streams sorted by staleness", expanded=False):
    if df_streams is not None and not df_streams.empty:
        dark_dataframe(df_streams, height=400)
    elif df_streams is not None:
        st.info("No stream data available.")

st.divider()

# --------------------------------------------------------------------------- #
# Current thresholds + tunability hint
# --------------------------------------------------------------------------- #

st.subheader("Current thresholds")
st.caption(
    "Tune thresholds without a redeploy: "
    "`UPDATE ad_analytics.ops.airbyte_freshness_thresholds "
    "SET warn_minutes=45 WHERE connection_id='fishbowl_s3';`"
)

if not df_conn.empty:
    threshold_cols = ["connection_id", "warn_minutes", "alert_minutes", "status"]
    cols_present = [c for c in threshold_cols if c in df_conn.columns]
    dark_dataframe(df_conn[cols_present])

st.divider()

# --------------------------------------------------------------------------- #
# Alert status section
# --------------------------------------------------------------------------- #

st.subheader("Alert objects")
st.markdown(
    f"""
    <div style="background:{BG_CHART};border-radius:8px;padding:1rem 1.2rem;">
      <p style="color:{TEXT_PRIMARY};font-size:0.9rem;margin:0 0 0.5rem 0;">
        Two Snowflake ALERT objects run at the same cadence as the dbt build
        (<code>cron 5,20,35,50 * * * ? UTC</code>) on <code>ETL_WH</code>.
      </p>
      <ul style="color:{TEXT_SECONDARY};font-size:0.85rem;margin:0;padding-left:1.2rem;">
        <li><strong style="color:{TEXT_PRIMARY};">ALERT_AIRBYTE_FRESHNESS_WARN</strong>
            — fires once when a connection first crosses the WARN threshold</li>
        <li><strong style="color:{TEXT_PRIMARY};">ALERT_AIRBYTE_FRESHNESS_ALERT</strong>
            — fires once when a connection first crosses the ALERT threshold</li>
      </ul>
      <p style="color:{TEXT_SECONDARY};font-size:0.82rem;margin:0.6rem 0 0 0;">
        Email destination: <code>victor@trinitybi.com</code> via
        <code>OPS_EMAIL_NOTIFICATIONS</code> integration.
        No recovery email is sent — silence means healthy.
        Runbook:
        <a href="https://github.com/trinitybi/dbt_ammodepot/blob/main/docs/AIRBYTE_INCIDENT_RUNBOOK.md"
           style="color:#00d4aa;">AIRBYTE_INCIDENT_RUNBOOK.md</a>
      </p>
    </div>
    """,
    unsafe_allow_html=True,
)
