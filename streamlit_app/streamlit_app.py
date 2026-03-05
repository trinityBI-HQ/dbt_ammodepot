"""Ammunition Depot Analytics — Streamlit App

Multi-page dashboard replacing Power BI reports.
Reads from Snowflake AD_ANALYTICS.GOLD layer.

Uses legacy pages/ directory pattern for SiS compatibility.
Pages are auto-discovered from pages/ directory (filenames set sidebar order).
"""

import streamlit as st

try:
    st.set_page_config(
        page_title="Ammunition Depot",
        layout="wide",
    )
except Exception:
    pass

st.title("Ammunition Depot Analytics")
st.markdown("Use the sidebar to navigate between dashboards.")

st.markdown("""
### Dashboards

- **Today / Yesterday** — Real-time daily KPIs, hourly sales, product performance
- **Sales Overview** — Historical sales by category (TODAY / MTD / YTD)
- **Inventory** — Stock levels, vendor analysis, open purchase orders
""")

with st.sidebar:
    st.caption("Analytics Dashboard v0.1")
