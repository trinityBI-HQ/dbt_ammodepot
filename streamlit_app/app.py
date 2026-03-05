"""Local development entrypoint.

Run: streamlit run app.py (from streamlit_app/ directory)
SiS entrypoint is streamlit_app.py (Snowflake convention).
Both use legacy pages/ directory pattern for sidebar navigation.
"""

import streamlit as st

st.set_page_config(
    page_title="Ammunition Depot",
    page_icon=":material/analytics:",
    layout="wide",
)

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
