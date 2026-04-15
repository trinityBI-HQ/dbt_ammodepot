"""Snowflake + AWS Cost & Usage Monitor — Streamlit in Snowflake entrypoint.

Runs on the SiS *container runtime* (Streamlit >=1.50, full PyPI).
Uses an External Access Integration to reach AWS Cost Explorer for
infrastructure cost breakdown alongside Snowflake compute/storage cost.

Local development entrypoint: ``app.py``.
"""

import streamlit as st

try:
    st.set_page_config(
        page_title="Snowflake + AWS Infra Monitor",
        page_icon=":material/monitoring:",
        layout="wide",
    )
except Exception:
    pass

st.title("Snowflake + AWS Infra Monitor")
st.markdown(
    "Unified compute, storage, infrastructure cost, and pipeline health "
    "monitoring for the Ammunition Depot analytics pipeline."
)

st.markdown(
    """
### Pages

- **Snowflake Compute** — Daily/MTD spend, warehouse + user + query-tag breakdown, daily anomalies
- **Snowflake Storage** — Storage growth by database (active + failsafe)
- **AWS Infrastructure** — ECS Fargate, EC2, S3 Iceberg, CloudWatch, Secrets Manager (MTD, daily 90d, monthly 6M)
- **Combined** — Total pipeline cost (Snowflake + AWS) with an explicit allow-list of what counts as AWS infrastructure
- **dbt Pipeline** — Build duration, build health, and interactive dbt documentation
"""
)

with st.sidebar:
    st.caption("Infra Monitor v0.2")
