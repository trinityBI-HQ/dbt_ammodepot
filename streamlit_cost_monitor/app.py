"""Local development entrypoint.

Run: ``streamlit run app.py`` from the ``streamlit_cost_monitor/`` directory.

SiS container entrypoint is ``streamlit_app.py`` (Snowflake convention).
Both use the legacy ``pages/`` directory pattern for sidebar navigation.

AWS Cost Explorer access differs by mode:
  - Local:  reads ``AWS_PROFILE=ammodepot`` from the shell.
  - SiS:    reads credentials from a Snowflake secret via ``_snowflake``
            using an External Access Integration.
"""

import streamlit as st

st.set_page_config(
    page_title="Snowflake + AWS Cost Monitor",
    page_icon=":material/savings:",
    layout="wide",
)

st.title("Snowflake + AWS Cost Monitor")
st.markdown(
    "Unified compute + storage + infrastructure cost tracking for the "
    "Ammunition Depot analytics pipeline."
)

st.markdown(
    """
### Pages

- **Snowflake Compute** — Daily/MTD spend, warehouse + user + query-tag breakdown, anomalies
- **Snowflake Storage** — Storage growth by database (active + failsafe)
- **Top Queries** — Most expensive queries across all warehouses (last 7 days)
- **AWS Infrastructure** — ECS Fargate, EC2, S3 Iceberg, CloudWatch, Secrets Manager
- **Combined** — Total pipeline cost (Snowflake + AWS) with month-over-month trend
"""
)

with st.sidebar:
    st.caption("Cost Monitor v0.1 — local")
