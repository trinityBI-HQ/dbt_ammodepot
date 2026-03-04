"""Ammunition Depot Analytics — Streamlit App

Multi-page dashboard replacing Power BI reports.
Reads from Snowflake AD_ANALYTICS.GOLD layer.

Entrypoint for both Streamlit in Snowflake (SiS) and local development.
SiS convention: entrypoint must be named streamlit_app.py.
"""

import streamlit as st

# st.set_page_config is not supported in SiS — wrap for compatibility
try:
    st.set_page_config(
        page_title="Ammunition Depot",
        page_icon=":material/analytics:",
        layout="wide",
    )
except Exception:
    pass

pages = {
    "Sales": [
        st.Page("pages/today_yesterday.py", title="Today / Yesterday", icon=":material/today:", default=True),
        st.Page("pages/sales_overview.py", title="Sales Overview", icon=":material/bar_chart:"),
    ],
    "Operations": [
        st.Page("pages/inventory.py", title="Inventory", icon=":material/inventory_2:"),
    ],
}

pg = st.navigation(pages)

with st.sidebar:
    st.title("Ammunition Depot")
    st.divider()
    st.caption("Analytics Dashboard v0.1")

pg.run()
