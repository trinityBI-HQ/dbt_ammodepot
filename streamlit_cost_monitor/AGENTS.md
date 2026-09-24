# streamlit_cost_monitor/ — the infra monitor

Streamlit in Snowflake app **`AD_ANALYTICS.OPS.INFRA_MONITOR`** — renamed from COST_MONITOR;
the directory kept its name to avoid CI churn. Six pages: Snowflake compute and storage,
AWS costs, combined, the dbt pipeline, Airbyte health. Setup and operation: `README.md`. Runtime
rules shared by all three apps: `../docs/architecture/streamlit-in-snowflake.md`.

- **Deploy is CI**: `deploy-streamlit-cost-monitor.yml` on push here, then re-attaches the EAI
  `aws_cost_explorer_integration` and the secret — `--replace` strips both.
- **AWS access** is the IAM user `svc_snowflake_costs` (policy `InfraMonitorReadOnly`: Cost Explorer,
  CloudWatch, Logs, the dbt-docs S3 prefix). Its key lives in the Snowflake secret
  `AD_ANALYTICS.OPS.AWS_COST_EXPLORER_CREDS`, never in the repo.
- **`setup/` runs in order, as ACCOUNTADMIN.** `07_airbyte_observability.sql` builds the freshness
  monitor behind page 6 and `08_airbyte_remediation_log.sql` the Lambda's audit table — both
  described in `../docs/architecture/airbyte-observability.md`.
- **dbt docs**: `deploy-dbt-docs.yml` publishes `dbt docs generate --static` to S3; page 5 links to a
  1-hour presigned URL with `st.link_button`, because the runtime blocks iframes.
- `ACCOUNT_USAGE` queries are cached for 1 h and CloudWatch queries for 5 min. The query helper
  lowercases column names.
