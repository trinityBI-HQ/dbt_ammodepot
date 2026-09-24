# dbt_ammodepot

Ammunition Depot's analytics platform: Fishbowl (ERP) and Magento (e-commerce) → Airbyte CDC → S3
Iceberg → Snowflake → dbt → Power BI and three Streamlit-in-Snowflake apps. The diagram is in
`README.md`.

**This file routes.** Each directory's `AGENTS.md` holds the rules for the code beside it and loads
when you work there; knowledge that is not a rule is in `docs/`.

## Where to look

| Working on | Read |
|---|---|
| dbt models, sources, macros | `ammodepot/AGENTS.md` |
| The production build, its schedule, a hotfix | `ecs/AGENTS.md` |
| The Airbyte host | `airbyte-ec2/AGENTS.md` |
| The auto-remediation Lambda | `lambda/airbyte_auto_remediate/AGENTS.md` |
| A Streamlit app | its directory's `AGENTS.md`; the runtime: `docs/architecture/streamlit-in-snowflake.md` |
| Databases, roles, warehouses, the lakehouse, cost | `docs/architecture/warehouse.md` |
| Forecasts, anomalies, Cortex | `docs/architecture/ai-features.md` |
| Freshness alerts and their thresholds | `docs/architecture/airbyte-observability.md` |
| Why something is the way it is | `docs/decisions/` |
| What broke before, and what it changed | `docs/incidents/` |
| A stuck sync, right now | `docs/AIRBYTE_INCIDENT_RUNBOOK.md` |
| Service users and grants | `docs/snowflake_access_setup.md`; Power BI's: `docs/sql/create_svc_powerbi.sql` |
| Cost tags, the cost dashboard | `snowflake_setup/01_governance_tags.sql`, `docs/SNOWFLAKE_COST_DASHBOARD.md` |

`archive/` is decommissioned — the Redshift project and what preceded the cutover — and runs nowhere.
Redshift's retirement, and the snapshot kept: `docs/decisions/0001-retire-redshift-keep-a-snapshot.md`.

## Invariants

- **`USE ROLE <role>;` opens every Snowflake SQL block.** No exceptions: the role follows the object
  being touched.
- **Production is whatever `main` builds.** ECS rebuilds from `:latest` every 15 minutes, so a change
  made to production that `main` does not carry is overwritten. Push first — `ecs/AGENTS.md`.
- **`COMPUTE_WH` is Power BI's.** Never rename, suspend or drop it; dbt and Airbyte run on `ETL_WH`.
- **`AD_AIRBYTE` is not dbt's.** Hand-written views live there and Power BI reads some of them; drop
  nothing in it without an audit.
- **Every AWS command takes `--profile ammodepot`.** IAM service users are named `svc_<purpose>`.
- **A change is done when `dbt build` passes** — and, when it moves row counts, when its before/after
  on production data is in the PR (`ammodepot/AGENTS.md`).
- **Work items live in Linear: team `TRI`, project Ammo Depot.**
- **`.claude/` is gitignored here**: it links the shared tooling and never enters this history.
  Anything that must reach a colleague goes in an `AGENTS.md` or under `docs/`.
