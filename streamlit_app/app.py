"""Local development entrypoint.

Run: streamlit run app.py (from streamlit_app/ directory)
SiS entrypoint is streamlit_app.py (Snowflake convention).
Both use legacy pages/ directory pattern for sidebar navigation.
"""

import pathlib
import streamlit as st

st.set_page_config(
    page_title="Ammunition Depot",
    page_icon=":material/analytics:",
    layout="wide",
)

# Logo
_logo_path = pathlib.Path(__file__).parent / "AmmoDepot.png"
col1, col2, col3 = st.columns([1, 1, 1])
with col2:
    st.image(str(_logo_path), width=250)

st.title("Ammunition Depot Analytics")
st.markdown("Use the sidebar to navigate between dashboards.")

st.markdown("""
### Dashboards

- **Today / Yesterday** — Real-time daily KPIs, hourly sales, product performance
- **Sales Overview** — Historical sales by category (TODAY / MTD / YTD)
- **Inventory** — Stock levels, vendor analysis, open purchase orders
""")

st.logo(str(_logo_path))

with st.sidebar:
    st.caption("Analytics Dashboard v0.1")
