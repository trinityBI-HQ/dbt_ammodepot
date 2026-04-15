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
    page_title="Snowflake + AWS Infra Monitor",
    page_icon=":material/monitoring:",
    layout="wide",
)

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
    st.caption("Infra Monitor v0.2 — local")
