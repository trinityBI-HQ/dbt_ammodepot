"""Ammunition Depot Analytics — Streamlit App

Multi-page dashboard replacing Power BI reports.
Reads from Snowflake AD_ANALYTICS.GOLD layer.
"""

import streamlit as st

st.set_page_config(
    page_title="Ammunition Depot",
    page_icon=":material/analytics:",
    layout="wide",
)

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
    st.image("https://ammunitiondepot.com/media/logo/stores/1/ammunition-depot-logo.png", width=200)
    st.divider()
    st.caption("Ammunition Depot Analytics v0.1")

pg.run()
