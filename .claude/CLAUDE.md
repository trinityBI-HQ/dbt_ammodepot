# ammodepot

## Institutional Memory

**Lookup policy:** For any technology question, check `.claude/kb/` before invoking an agent or using Exa web search. See the KB routing table in the institutional CLAUDE.md for technology-to-path mapping.

**Model guidance:** `.claude/docs/07_MODEL_SELECTION_POLICY.md` — Haiku for lookups/summaries, Sonnet for implementation, Opus for architecture decisions.

---

## Project Context

dbt project for Ammunition Depot's analytics pipeline. Transforms raw data from Fishbowl (inventory/ERP) and Magento (e-commerce) into structured, tested datasets using Medallion Architecture.

Data is ingested via Airbyte CDC, then transformed through Bronze, Silver, and Gold layers.

### Warehouse Migration (Complete)

Migrated from **Amazon Redshift** to **Snowflake**. Redshift project archived.
- **Snowflake** (`ammodepot/`): Production — 104 models, ECS Fargate orchestration every 15 min synced to PBI (cron at :05/:20/:35/:50)
- **Redshift** (`archive/projects/ammodepot/`): Archived — no longer running
- **Adapter**: dbt-snowflake 1.11.2

### Snowflake Database Architecture (post-Iceberg cutover, 2026-04-07)

```
S3 Iceberg (Glue catalog)          AD_ANALYTICS (TRANSFORMER_ROLE)
└── ammodepot-lakehouse/           ├── LAKEHOUSE_LANDING (55 UNMANAGED Iceberg tables)
    ├── production2018/            │      ↑ Snowflake reads via External Volume
    └── ammuni_prod/               │        + Glue Catalog Integration
                                   ├── SILVER (69 views + 7 tables)
                                   └── GOLD (14 tables + 14 views)
                                          ↑ Power BI reads here

AD_AIRBYTE (legacy, no longer written to — kept readable for fallback)
```

- **Roles**: `AIRBYTE_ROLE` (ingestion), `TRANSFORMER_ROLE` (dbt), `POWERBI_ROLE` (read-only BI), `POWERBI_READONLY_ROLE` (Gold + Streamlit viewer), `STREAMLIT_ROLE` (app owner), `DASHBOARD_VIEWER_ROLE` (SSO viewers)
- **Service accounts**: `SVC_AIRBYTE` (key-pair), `SVC_DBT` (key-pair), `POWERBI_READER` (password, `POWERBI_READONLY_ROLE` — carries actual PBI credits), `POWERBI_AD` (AD-synced PBI account), `PC_FIVETRAN_USER` (legacy Fivetran, low usage). `SVC_POWERBI` was documented in `docs/snowflake_access_setup.md` §11 but never provisioned. Legacy `AIRBYTE` user (pre-SVC naming) also exists — verify before tagging.
- **Warehouses**: `ETL_WH` (XSMALL, auto-suspend 60s, Airbyte + dbt), `COMPUTE_WH` (XSMALL, BI — used by Power BI, do NOT rename/drop/suspend)
- **Legacy warehouse**: `PC_FIVETRAN_WH` (was $540/mo Fivetran). NOT fully dormant — `POWERBI_AD` still runs ~286 queries/week here (likely a stray dataflow refresh). Audit + kill or migrate to COMPUTE_WH as a follow-up.
- **Query tags**: All users tagged via `QUERY_TAG` for cost attribution
- **Cost monitoring**: Snowsight dashboard "Snowflake Cost & Usage Monitor" (8 tiles, see `docs/SNOWFLAKE_COST_DASHBOARD.md`)
- **Pre-cutover credits (30d)**: ETL_WH ~2,053 ($6,159), COMPUTE_WH ~62 ($186), total ~2,464 credits ($7,392)
- **Pre-cutover cost by user**: SVC_AIRBYTE 678 (74%), SVC_DBT 137 (15%), POWERBI_READER 103 (11%)
- **Realized savings**: ~$847/mo (dbt Cloud + EC2 downsize + MWAA) + **~$2,034/mo (Iceberg cutover, 2026-04-07)** = **~$2,881/mo total / ~$34,572/year**
- **Streamlit compute pools**: `cost_monitor_pool` (~$5/mo) + `sales_dashboard_pool` (~$5/mo, shared with Analyst chatbot) = ~$10/mo incremental

---

## Architecture Overview

```
Airbyte CDC (Fishbowl, Magento)
         |
         v
+- Bronze (source definitions) ---------------+
|  Source YAMLs only, no SQL models            |
|  Schema: fishbowl, magento                   |
+------------------+---------------------------+
                   v
+- Silver (views) -----------------------------+
|  Column rename, CDC filter, type casting     |
|  Schema: silver                              |
+------------------+---------------------------+
                   v
+- Gold (tables + intermediate views) ---------+
|  Business logic, joins, consumption-ready    |
|  Schema: gold                                |
+----------------------------------------------+
```

| Component | Technology |
|---|---|
| Transformation | dbt-core 1.11.6 + dbt-snowflake 1.11.2 |
| Warehouse | Snowflake (production, reads Iceberg via External Volume) |
| Ingestion | Airbyte CDC on EC2 c6a.2xlarge → S3 Iceberg (Glue catalog). Legacy → Snowflake connections inactive 2026-04-07 |
| Bronze refresh | `on-run-start` hook: `ALTER ICEBERG TABLE ... REFRESH` for all 55 LAKEHOUSE_LANDING tables before each build |
| Orchestration | ECS Fargate Spot (every 15 min, synced to PBI: cron `5,20,35,50 * * * ? *` UTC — fires 5 min before each PBI :00/:15/:30/:45 refresh) + EventBridge scheduler |
| CI/CD | GitHub Actions → ECR on push to main (path-filtered: ammodepot/, ecs/); Streamlit deploys via `snow streamlit deploy` (path-filtered: streamlit_app/, streamlit_cost_monitor/, streamlit_analyst/) |
| Packages | dbt_utils |
| Cross-db macros | `adapter.dispatch` for `json_extract_text`, `convert_tz`, `string_agg`, `format_timestamp` |
| Linting | SQLFluff (Snowflake dialect) |
| Python | uv (package manager) |
| BI Dashboard | Streamlit (`AD_ANALYTICS.OPS.SALES_DASHBOARD`, SiS container runtime) + Snowsight dashboards |
| Infra Monitoring | Snowsight dashboard (8 tiles) + Streamlit infra monitor app (`AD_ANALYTICS.OPS.INFRA_MONITOR`, SiS container runtime, 5 pages: SF Compute, SF Storage, AWS Infra, Combined, dbt Pipeline) |
| AI Analyst | Streamlit chatbot (`AD_ANALYTICS.OPS.ANALYST`, SiS container runtime) powered by Snowflake Cortex Analyst + Semantic View |
| Demand Forecasting | Snowflake Cortex ML (FORECAST) — 115 calibers + revenue, weekly Task `TASK_DAILY_FORECAST` (Sunday 4am UTC), outputs to `F_FORECAST` |
| Anomaly Detection | Snowflake Cortex ML (ANOMALY_DETECTION) — revenue, orders, margin; alert banner on Page 1, outputs to `F_ANOMALIES` |
| Churn Narratives | Snowflake Cortex LLM (`llama3.1-70b`) — Page 5 RFM segment health + executive summary, reads `D_CUSTOMER_SEGMENTATION` |
| Reorder Intelligence | dbt Gold table `F_REORDER_RECOMMENDATIONS` + CORTEX.COMPLETE — per-caliber reorder qty + vendor, Page 4 tab |
| EC2 Maintenance | Bash scripts (cron-scheduled cleanup + disk alerts) |
| Archive | Decommissioned Redshift project + old artifacts |

---

## Streamlit Dashboard App

Replacement for Power BI dashboards, deployed to Streamlit in Snowflake (SiS) on container runtime.

- **Deployed to**: `AD_ANALYTICS.OPS.SALES_DASHBOARD` (SiS container runtime, Streamlit 1.55+)
- **Compute pool**: `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s, ~$5/mo)
- **EAI**: `sales_dashboard_integration` — egress to `basemaps.cartocdn.com` (CARTO tiles) + `pypi.org` + `files.pythonhosted.org`
- **CI/CD**: `.github/workflows/deploy-streamlit-dashboard.yml` — triggers on push to `streamlit_app/`; re-attaches EAI after every `snow streamlit deploy --replace`

```
streamlit_app/
├── app.py                         # Entry point (local) (~38 lines)
├── streamlit_app.py               # Entry point (SiS) (~32 lines)
├── snowflake.yml                  # SiS definition v2 — container runtime, sales_dashboard_pool
├── requirements.txt               # streamlit>=1.55, pandas, plotly, snowflake-snowpark-python
├── setup/
│   └── 01_bootstrap.sql           # ACCOUNTADMIN one-time: pool, EAI, network rules, grants
├── pages/
│   ├── 1_Today_Yesterday.py       # Real-time sales + cross-filtering + anomaly alert banner (replaces PBI SALES OVERVIEW FASTER) ~1,405 lines
│   ├── 2_Sales_Overview.py        # Historical sales with category pages + cross-filtering (replaces PBI SALES OVERVIEW) ~1,527 lines
│   ├── 3_Inventory.py             # Inventory + Vendor Analysis + Open POs (replaces PBI INVENTORY) ~1,272 lines
│   ├── 4_Forecast.py             # Demand forecast + 5 tabs: Stock-Out Risk, Caliber Forecast, Revenue Forecast, Reorder Recommendations (+ Vendor Comparison), Forecast Accuracy (~697 lines)
│   └── 5_Customer_Intelligence.py # RFM segment health + llama3.1-70b executive summary + MoM deltas (AI Phase 4) (~440 lines)
├── test_forecast_backtest.py     # Forecast accuracy backtest harness
└── utils/
    ├── __init__.py
    ├── chart_theme.py             # Unified dark theme for Plotly charts + HTML tables (~127 lines)
    ├── db.py                      # Query runner, _is_sis flag, numeric/timestamp coercion (~158 lines)
    └── zip3_coords.py             # 886-entry ZIP3→(lat,lon) centroid lookup for maps (~345 lines)
```

**Total:** ~6,221 lines across 12 Python files

### Cross-Filtering (PBI-style)

Pages 1 and 2 implement PBI-style cross-filtering with selectbox dropdowns + clickable Plotly charts:
- **Session state keys**: `ty_xf_cat`, `ty_xf_mfr`, `ty_xf_vendor`, `ty_xf_sku`, `ty_xf_cust` (Today/Yesterday) and `so_xf_mfr`, `so_xf_vendor`, `so_xf_sku`, `so_xf_cust` (Sales Overview)
- **Pending-state pattern**: Chart clicks store `(key, value)` in `_ty_xf_pending`/`_so_xf_pending`, consumed before widget rendering on next rerun
- **`on_click` callback**: Clear All button uses `st.button(on_click=fn)` — avoids `StreamlitAPIException` from setting widget keys after instantiation
- **Active filter pills**: HTML spans with colored badges showing current filters
- **Bar dimming**: Non-selected Plotly bars render at 20% opacity when a filter is active
- **Clickable charts**: Enabled in both local and SiS (container runtime 1.55+); `not callable(sel)` guard handles edge cases defensively
- **Dropdown options**: Built from pre-filter data (PBI behavior — show all values regardless of active filters)

### Dark Theme Architecture

All visual components force a unified dark background (`#1E1E1E`) via `utils/chart_theme.py`:
- **`apply_theme(fig)`**: Forces dark `plot_bgcolor`/`paper_bgcolor`, light text, subtle grid on all Plotly `go.Figure` charts
- **`dark_dataframe(df)`**: Renders DataFrames as dark HTML tables via `st.markdown` — replaces all `st.dataframe` calls (SiS iframe can't be styled with external CSS)
- **`secondary_axis_style()`**: Returns color + tickfont dict for yaxis2
- **Inventory HTML bars**: Wrapped in `<div style="background:#1E1E1E">` containers with light text
- **Constants**: `BG_CHART`, `ACCENT`, `TEXT_PRIMARY`, `TEXT_SECONDARY`, `GRID_COLOR` shared across all pages

### SiS Compatibility Notes

- **Runtime**: Container runtime (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`, Streamlit 1.55+) — migrated from warehouse runtime 2026-04-14
- **Plotly**: Use `go.Bar`/`go.Figure` with `.tolist()` — `px.bar` fails serialization in SiS
- **Plotly x-axis**: Use numeric positions + `tickvals`/`ticktext` to avoid duplicate category merging
- **Plotly on_select**: `on_select="rerun"` enabled in SiS (1.55+); `not callable(sel)` defensive guard retained
- **Maps**: `go.Scattermap` with CARTO `carto-darkmatter` tiles — requires EAI egress to `basemaps.cartocdn.com`
- **Data types**: All plotly data must be plain Python types (`float()`, `.tolist()`), not numpy/pandas
- **Dual-mode**: `_is_sis` flag in `utils/db.py` controls session/connection routing (no rendering guards remain). SiS session runs `USE SCHEMA AD_ANALYTICS.GOLD` on init — Streamlit object lives in OPS but queries target GOLD
- **st.dataframe**: Renders inside iframe that ignores external CSS on SiS — use `dark_dataframe()` instead
- **Theme detection**: `st.get_option("theme.base")` unreliable on SiS — force dark backgrounds explicitly
- **Session state pattern**: Initialize defaults in `st.session_state`, render widgets with `key=` only (no `value=`)
- **Full-width CSS**: All pages inject CSS to remove Streamlit default max-width padding
- **PBI data filters**: Vendor Analysis + Open POs filter to `Ammunition` category + `QTY != 0` (matches PBI)
- **KPI cards**: Custom HTML/CSS with `st.markdown(unsafe_allow_html=True)` — PBI-style icons, colored borders
- **Default filters**: Order Status preselected to COMPLETE, PROCESSING, UNVERIFIED (matches PBI)
- **`--replace` strips EAI**: CI step re-attaches `sales_dashboard_integration` after every deploy (same pattern as cost monitor)

---

## Project Structure

### Snowflake Project (Production)

```
ammodepot/
├── dbt_project.yml             # version 2.0
├── packages.yml
├── profiles.yml                # Committed (env_var() only, no secrets)
├── .env                        # Not committed (.gitignore)
├── .env.example                # Snowflake-only connection vars
├── .sqlfluff                   # dialect: snowflake
├── macros/
│   ├── generate_schema_name.sql
│   ├── json_extract_text.sql   # Cross-dialect JSON extraction (adapter.dispatch)
│   ├── ml_forecast.sql         # 4 ML training macros (train_caliber_forecast, train_revenue_forecast, train_anomaly_models, train_all_ml_models)
│   └── cross_db/               # Cross-dialect dispatch macros
│       ├── convert_tz.sql
│       ├── string_agg.sql
│       └── format_timestamp.sql
├── tests/generic/              # 8 custom generic tests
├── models/
│   ├── bronze/                 # Source definitions (reads from AD_AIRBYTE + PC_FIVETRAN_DB)
│   │   ├── fishbowl/           # schema: AD_FISHBOWL (34 source tables)
│   │   ├── magento/            # schema: AD_MAGENTO (25 source tables)
│   │   └── ups/                # schema: UPS_INVOICE_HISTORY in PC_FIVETRAN_DB (1 source table)
│   ├── silver/                 # 76 models (69 views + 7 high-fan-out tables)
│   └── gold/                   # 13 table models + 14 views (including intermediates)
│       ├── intermediate/       # 14 reusable view models (3 materialized as tables)
│       ├── _exposures.yml      # BI dashboard dependency documentation
│       ├── f_cohort.sql        # Customer cohort analysis
│       ├── f_cohort_detailed.sql  # Detailed cohort metrics
│       └── f_sales_realtime.sql   # Real-time sales (filtered view of f_sales)
├── seeds/
│   └── customer_groups.csv     # Customer group lookup (Law Enforcement, Wholesale, etc.)
├── snapshots/
│   └── snap_customer_segmentation.sql  # check strategy on RFM classification fields; target: gold
└── analyses/
```

**Snowflake Counts:** 104 models (34 FB + 23 MG + 19 Inv + 14 Gold + 14 Int), 1 snapshot, 1 seed, 56 source tables (34 FB + 21 MG + 1 UPS), 8 generic tests, 6 macros (3 root + 3 cross_db), 5 exposures

### Lakehouse (Iceberg via Snowflake — CUTOVER COMPLETE 2026-04-07)

The standalone `ammodepot_lakehouse/` dbt-duckdb project was removed during cutover (commit `e08218bc`). Snowflake now reads S3 Iceberg directly via External Volume + Glue Catalog Integration:

- **External Volume**: `LAKEHOUSE_S3_VOLUME` → `s3://ammodepot-lakehouse/`
- **Catalog Integration**: `LAKEHOUSE_GLUE_CATALOG` → AWS Glue (`production2018`, `ammuni_prod`)
- **Iceberg tables**: 55 UNMANAGED tables in `AD_ANALYTICS.LAKEHOUSE_LANDING` (34 Fishbowl + 21 Magento)
- **Refresh**: Manual via `ALTER ICEBERG TABLE ... REFRESH` — wired into dbt's `on-run-start` hook (`ammodepot/macros/refresh_lakehouse_landing.sql`)
- **Bronze sources**: All `bronze_*_sources.yml` point to `database: AD_ANALYTICS, schema: LAKEHOUSE_LANDING` with explicit `identifier:` mapping
- **Type pitfalls**: Iceberg writes `_airbyte_extracted_at` as NUMBER (epoch ms) vs legacy TIMESTAMP_TZ; business timestamps come through as TIMESTAMP_LTZ vs legacy TIMESTAMP_TZ. Silver models use `to_timestamp(_airbyte_extracted_at, 3)`. Gold models that feed Power BI cast convert_timezone results back to TIMESTAMP_NTZ to preserve the cached PBI schema.

### Streamlit App (BI Dashboard — SiS container runtime)

```
streamlit_app/                          # See "Streamlit Dashboard App" section above
```

### Streamlit Infra Monitor App (renamed from Cost Monitor, 2026-04-15)

```
streamlit_cost_monitor/                    # Directory name kept to avoid CI churn
├── streamlit_app.py               # Entry point (SiS)
├── app.py                         # Entry point (local)
├── snowflake.yml                  # SiS definition v2 — container runtime, cost_monitor_pool
├── requirements.txt               # streamlit>=1.55, pandas, plotly, boto3, snowflake-snowpark-python
├── pages/
│   ├── 1_Snowflake_Compute.py     # MTD KPIs, daily trend by warehouse + user, anomaly detector
│   ├── 2_Snowflake_Storage.py     # DB snapshot + 30d growth stacked area
│   ├── 3_AWS_Infrastructure.py    # MTD KPIs, daily/monthly service spend, boto3 via EAI
│   ├── 4_Combined.py              # 6M monthly SF+AWS trend, MTD totals
│   └── 5_dbt_Pipeline.py          # Build duration chart, build health table, dbt docs link
├── utils/
│   ├── config.py                  # CREDIT_PRICE_USD, lookback windows, CW constants, S3 docs config
│   ├── db.py                      # Snowpark session (active session in SiS, key-pair local)
│   ├── snowflake_queries.py       # All ACCOUNT_USAGE SQL (mtd_summary, daily_cost_*, anomalies)
│   ├── aws_costs.py               # boto3 client factory (get_boto3_client), Cost Explorer queries
│   └── cloudwatch_metrics.py      # CloudWatch Metrics + Logs queries, S3 presigned URL
└── setup/
    ├── 01_bootstrap.sql           # ACCOUNTADMIN one-time: schema, stage, compute pool, EAI
    ├── 02_create_secret.sql       # Write real AWS key to Snowflake secret
    ├── 03_post_deploy.sql         # Attach EAI + viewer grants (now superseded by CI step)
    ├── 04_fix_pypi_access.sql     # Add PyPI egress to EAI (one-time fix, 2026-04-09)
    ├── 05_add_cloudwatch_egress.sql  # Add CloudWatch + Logs + S3 egress to EAI
    └── 06_rename_and_grant.sql    # Drop old COST_MONITOR, re-grant viewers on INFRA_MONITOR
```

- **Deployed to**: `AD_ANALYTICS.OPS.INFRA_MONITOR` (SiS container runtime, Streamlit 1.55+)
- **Compute pool**: `cost_monitor_pool` (CPU_X64_XS, 1 node, auto-suspend 300s, ~$5/mo)
- **EAI**: `aws_cost_explorer_integration` — egress to CE + PyPI + CloudWatch + Logs + S3
- **Secret**: `AD_ANALYTICS.OPS.AWS_COST_EXPLORER_CREDS` — generic-string `{"access_key":...,"secret_key":...}` for IAM user `svc_snowflake_costs`
- **IAM**: `svc_snowflake_costs` policy `InfraMonitorReadOnly` — CE + CloudWatch + Logs + S3 (dbt-docs prefix)
- **CI/CD**: `.github/workflows/deploy-streamlit-cost-monitor.yml` — triggers on push to `streamlit_cost_monitor/`; re-attaches EAI + secret after every `snow streamlit deploy --replace`
- **dbt Docs CI**: `.github/workflows/deploy-dbt-docs.yml` — triggers on push to `ammodepot/`; runs `dbt docs generate --static`, uploads `static_index.html` to `s3://ammodepot-lakehouse/dbt-docs/index.html`
- **dbt Docs access**: Page 5 generates 1-hour presigned S3 URL via `st.link_button` (SiS CSP blocks iframes to external URLs)
- **ACCOUNT_USAGE queries**: All wrapped in `st.cache_data(ttl="1h")`; CloudWatch queries cached 5 min
- **Viewers**: `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` granted USAGE on Streamlit object

### Streamlit Analyst App (Cortex Analyst Chatbot)

```
streamlit_analyst/
├── app.py                         # Entry point (local) (~124 lines)
├── streamlit_app.py               # Entry point (SiS) (~152 lines)
├── snowflake.yml                  # SiS definition v2 — container runtime, sales_dashboard_pool
├── requirements.txt               # streamlit>=1.55, requests, pandas, snowflake-snowpark-python
├── test_golden_questions.py       # Automated golden question smoke test (25 questions) (~175 lines)
├── .streamlit/
│   └── config.toml                # Dark theme config
├── setup/
│   └── 01_bootstrap.sql           # ACCOUNTADMIN one-time: semantic view + RBAC grants + stage (~847 lines)
└── utils/
    ├── __init__.py
    ├── analyst.py                 # Cortex Analyst REST API wrapper + response parser (~108 lines)
    ├── chart_theme.py             # Minimal theme constants (~7 lines)
    └── db.py                      # Dual-mode Snowflake connection (SiS/local) (~89 lines)
```

**Total:** ~1,529 lines across 10 files (7 Python, 2 SQL/TOML, 1 YAML)

- **Deployed to**: `AD_ANALYTICS.OPS.ANALYST` (SiS container runtime, Streamlit 1.55+)
- **Compute pool**: `sales_dashboard_pool` (shared with Sales Dashboard — no incremental cost)
- **Query warehouse**: `COMPUTE_WH`
- **Semantic View**: `AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST` — covers 6 Gold tables (F_SALES, F_INVENTORYVIEW, F_POS, INT_PRODUCT_ANALYST, D_VENDOR, D_CUSTOMER_SEGMENTATION) with 20 verified golden queries
- **dbt dependency**: `int_product_analyst` (new intermediate view) — re-aliases quoted D_PRODUCT columns to UPPERCASE unquoted for Cortex Analyst compatibility
- **Authentication**: SiS container runtime reads OAuth token from `/snowflake/session/token`; local dev uses snowflake-connector REST token
- **API**: REST POST to `/api/v2/cortex/analyst/message` with full conversation history for multi-turn context
- **CI/CD**: `.github/workflows/deploy-streamlit-analyst.yml` — triggers on push to `streamlit_analyst/`; uses `snow streamlit deploy --replace`
- **Viewers**: `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` + `STREAMLIT_ROLE` granted SELECT on semantic view

### Airbyte EC2 Maintenance Scripts

```
airbyte-ec2/
├── airbyte-cleanup.sh      # Monthly cleanup: Minio logs + DB pruning + VACUUM (~123 lines)
├── disk-alert.sh           # 6-hourly disk usage alert to log (~43 lines)
└── deploy.sh               # One-command installer for EC2 (~76 lines)
```

- **Deployed to**: `/opt/` on EC2 instance `i-075043415ebad732f` (c6a.2xlarge, 8 vCPU, 16 GB, AL2023, ~$223/mo)
- **Airbyte**: v2.0.1 (Chart 2.0.19), abctl v0.30.4 (kind/k8s), EIP 18.204.90.52
- **Old instance**: `i-0c6727e56deafaf36` (AL2, pending termination)
- **Cron**: Monthly cleanup (1st at 3am UTC), disk alert (every 6h)
- **Logs**: `/var/log/airbyte-cleanup.log`, `/var/log/disk-alert.log`
- **Dry run**: `sudo /opt/scripts/airbyte-cleanup.sh --dry-run`
- **Docs**: see `docs/` folder

### ECS Fargate (dbt Orchestration)

```
ecs/
├── Dockerfile                 # Python 3.11-slim + uv + dbt-snowflake (~40s build)
├── entrypoint.sh              # Writes RSA key, source freshness (JSON), dbt build --target prod, dbt snapshot (non-fatal)
├── deploy.sh                  # Manual deploy fallback (build + push to ECR)
├── pyproject.toml             # Minimal deps: dbt-core + dbt-snowflake
├── task-definition.json       # 0.5 vCPU, 1 GB, Secrets Manager refs
├── eventbridge-rule.json      # cron(5,20,35,50 * * * ? *) — sync 5 min ahead of PBI
├── iam-policies/              # Least-privilege IAM role policies
│   ├── task-execution-trust.json
│   ├── task-execution-role.json
│   ├── eventbridge-trust.json
│   └── eventbridge-role.json
└── README.md                  # Full deployment guide
```

- **CI/CD**: GitHub Actions (`deploy-ecs.yml`) auto-builds + pushes to ECR on push to main (path-filtered: ammodepot/, ecs/)
- **Cluster**: `ammodepot-dbt` (Fargate Spot, us-east-1)
- **Task**: `ammodepot-dbt-build` (0.5 vCPU, 1 GB, ~3 min/run)
- **Schedule**: EventBridge `cron(5,20,35,50 * * * ? *)` UTC — fires 5 min before each PBI :00/:15/:30/:45 refresh; picks up new `:latest` image automatically
- **Network**: Private subnets in airbyte-project VPC
- **Secrets**: `ammodepot/dbt/snowflake` (Secrets Manager — RSA key + passphrase)
- **Logs**: CloudWatch `/ecs/ammodepot-dbt`
- **Monitoring**: CloudWatch dashboard `ammodepot-dbt` (build results, duration, warnings, errors)
- **Alerts**: `dbt-build-failure` (matches `[31mERROR` in build output, freshness stderr suppressed), `dbt-task-missing` (no runs in 30 min) → SNS email
- **Cost**: ~$3.70/month total (replaces dbt Cloud at $663/mo)
- **ECR**: `746669199691.dkr.ecr.us-east-1.amazonaws.com/ammodepot/dbt`
- **AWS CLI user**: `svc_iac` (ADBIadmin group, CLI-only, `--profile ammodepot`; also used for GitHub Actions via secrets)
- **Manual deploy**: `./ecs/deploy.sh` from repo root (fallback when CI is unavailable)

### Archive (Decommissioned)

```
archive/
├── projects/ammodepot/                # Redshift dbt project (migrated to Snowflake)
└── target/                            # Old dbt build artifacts
```

- **MWAA**: Deleted 2026-03-23 (~$450/mo saved). Archive files removed from repo 2026-03-25 (contained leaked credentials).

---

## Coding Standards

### SQL / dbt

- **No `SELECT *`** -- all models use explicit column lists
- **CDC filtering** -- all Silver models filter with `WHERE _ab_cdc_deleted_at IS NULL`
- **Column aliasing** -- Silver uses snake_case; Gold uses UPPER_CASE for BI compatibility
- **CTE pattern** -- `WITH source_data AS (...) SELECT ... FROM source_data`
- **Explicit column lists** -- enumerate all columns, no implicit selection
- **COALESCE for NULLs** -- defensive null handling throughout
- **Business values parameterized** -- dbt variables in `dbt_project.yml`, zero hardcoded values
- **All config in dbt_project.yml** -- no per-model `{{ config() }}` blocks
- **SQL keywords lowercase** -- enforced by sqlfluff
- **Silver dedup guards** -- all 55 Fishbowl+Magento Silver models use `QUALIFY ROW_NUMBER()` to prevent duplicate rows
- **Cross-db dispatch macros** -- use `adapter.dispatch` for dialect-specific SQL (`convert_tz`, `string_agg`, `format_timestamp`, `json_extract_text`); dispatch search order configured in `dbt_project.yml`

### Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| Source YAML | `bronze_{source}_sources.yml` | `bronze_fishbowl_sources.yml` |
| Silver model | `{source}_{entity}.sql` | `fishbowl_so.sql`, `magento_sales_order.sql` |
| Silver YAML | `_{source}__models.yml` | `_fishbowl__models.yml` |
| Gold dimension | `d_{entity}.sql` | `d_product.sql` |
| Gold fact | `f_{entity}.sql` | `f_sales.sql` |
| Intermediate | `int_{source}_{purpose}.sql` | `int_fishbowl_order_cost.sql` |
| Inventory model | `inventory_{metric}.sql` | `inventory_qtyonhand.sql` |
| Generic test | `assert_{check}.sql` | `assert_non_negative_values.sql` |

### Materialization Rules

| Layer | Default | Notes |
|---|---|---|
| Bronze | Source YAML only | No SQL models -- Airbyte loads directly |
| Silver | `view` | Lightweight, real-time freshness; 7 high-fan-out models override to `table` |
| Gold | `table` | Consumption-ready for BI tools; `+transient: true`, `+query_tag: 'dbt:gold'`; f_sales uses `incremental` (merge, 3-day lookback) |
| Intermediate | `view` | Reusable pre-computation for Gold tables; 3 critical bottlenecks override to `table` (int_fishbowl_order_cost, int_magento_product_eav_lookups, int_sales_cost_fallback) |

### Schema Routing

`generate_schema_name` macro routes schemas:
- **Production** (`target.name == 'prod'`): Uses layer schemas (`silver`, `gold`)
- **Development**: All models in `target.schema` (e.g. `dbt_dev`) for isolation

---

## Sources

### Fishbowl (34 tables, both projects)
Inventory management / ERP system. Key tables: `so`, `soitem`, `product`, `part`, `vendor`, `ship`, `po`, `poitem`, `receipt`, `receiptitem`, `uomconversion`, `kititem`, `objecttoobject`
- Redshift: `fishbowl` schema | Snowflake: `AD_AIRBYTE.AD_FISHBOWL`

### Magento (21 tables in Snowflake project, 29 Airbyte streams)
E-commerce platform. Key tables: `sales_order`, `sales_order_item`, `customer_entity`, `catalog_product_entity`, `quote`, `store`, EAV attribute tables (`eav_attribute`, `catalog_product_entity_varchar/int/text/decimal`)
- Redshift: `magento` schema | Snowflake: `AD_AIRBYTE.AD_MAGENTO`

### UPS (1 table, Snowflake only)
Shipping invoice data manually uploaded weekly from UPS Billing Center CSV exports. Loaded into `PC_FIVETRAN_DB.UPS_INVOICE_HISTORY` by operations team.
- Key table: `ups_invoice` (tracking_number, net_amount)
- Joins to Fishbowl shipcarton via tracking_number for freight cost allocation

### Source Freshness
Fishbowl and Magento sources have freshness configured: warn after 24h, error after 48h, using `_airbyte_extracted_at` as the loaded_at_field. UPS source has no freshness check (manual upload cadence).

### Airbyte Connections (4 active, updated 2026-04-06)

| # | Connection | Dest | Frequency | Streams | Status |
|---|---|---|---|---|---|
| 1 | Fishbowl → Snowflake | SF | 10 min | 35 | **Active** (31.5M rows synced) |
| 2 | Magento → Snowflake | SF | 10 min | 28 | **Active** |
| 3 | Fishbowl → S3 Iceberg | S3 | Manual | 34 | **Ready** |
| 4 | Magento → S3 Iceberg | S3 | Manual | 21 | **Ready** |

- **Cost impact**: SVC_AIRBYTE consumes 678 credits/mo (74% of total compute)
- **Full audit**: `Connections Audit - Ammo Depot.xlsx` (per-stream detail)

### EAV Pattern
Magento uses Entity-Attribute-Value for product attributes. Product attributes are resolved in `int_magento_product_eav_lookups.sql` and `int_magento_product_attributes.sql`, then consumed by `d_product.sql`. Attribute IDs are configured as dbt variables with prefix `ammodepot_magento_attr_id_*`.

---

## Common Commands

### Snowflake Project (from `ammodepot/`)

```bash
# IMPORTANT: dbt doesn't auto-load .env — must source it first
set -a && source .env && set +a && uv run dbt build --profiles-dir . --target prod
set -a && source .env && set +a && uv run dbt parse --profiles-dir .
set -a && source .env && set +a && uv run dbt test --profiles-dir . --target prod --select gold
```

### AWS CLI (use `--profile ammodepot` for all commands)

```bash
aws ecs list-tasks --cluster ammodepot-dbt --profile ammodepot
aws logs tail /ecs/ammodepot-dbt --since 1h --profile ammodepot
aws ecr describe-images --repository-name ammodepot/dbt --profile ammodepot
```

---

## Key Design Decisions

1. **Airbyte CDC over Fivetran** -- Sources use `_ab_cdc_deleted_at` and `_ab_cdc_updated_at` columns for change tracking.

2. **Bronze = source definitions only** -- ammodepot's Bronze layer is purely YAML source definitions. Airbyte loads directly into `fishbowl.*` and `magento.*` schemas.

3. **Silver views, Gold tables** -- Silver is lightweight (views) for real-time freshness, with 7 high-fan-out models overridden to tables (fishbowl_soitem, fishbowl_product, fishbowl_uomconversion, fishbowl_part, magento_sales_order_item, magento_sales_order, inventory_qtyinventorytotals). Gold materializes as tables for BI query performance.

4. **Intermediate views in Gold schema** -- Complex CTEs extracted from `f_sales` and `d_product` into 14 reusable intermediate views, materialized in the `gold` schema. Includes `int_fishbowl_magento_order_map` (NUM-based SO-to-order mapping), `int_sales_cost_fallback` (cost fallback logic extracted from f_sales), `int_magento_product_eav_lookups` (single-scan pivot for EAV resolution), `int_customer_cohort` (shared cohort base for f_cohort/f_cohort_detailed), `int_product_analyst` (UPPERCASE unquoted re-alias of D_PRODUCT for Cortex Analyst compatibility), `int_daily_sales_by_caliber` (forecast training input), and `int_daily_sales_metrics` (anomaly detection training input).

5. **UPPER_CASE gold columns** -- Gold layer output uses UPPER_CASE aliases for backward compatibility with existing Power BI consumers.

6. **EAV attribute parameterization** -- Magento attribute IDs are configured as dbt variables to avoid hardcoding numeric IDs in SQL.

7. **All config centralized** -- Model materialization and schema routing defined in `dbt_project.yml`, not in per-model config blocks.

8. **Generic tests in `tests/generic/`** -- 8 reusable test macros using `{% test %}` wrapper syntax (reduced from 16 after dead code cleanup).

9. **Snowflake migration** -- Separate Snowflake dbt project (`ammodepot/`) with 3 new Gold models (f_cohort, f_cohort_detailed, f_sales_realtime). `AD_AIRBYTE` database for sources (AD_FISHBOWL/AD_MAGENTO schemas), `AD_ANALYTICS` database for Silver/Gold output. Three roles: `TRANSFORMER_ROLE` (dbt), `AIRBYTE_ROLE` (ingestion), `POWERBI_ROLE` (read-only BI).

10. **No column removals/renames without Power BI coordination** -- Gold layer tables are consumed directly by Power BI dashboards. Any column removal, rename, or type change requires coordinated BI update. Pipeline details are documented in CLAUDE.md and the archive.

11. **Cross-db dispatch macros** -- All dialect-specific SQL uses `adapter.dispatch` pattern (`macros/cross_db/`). Dispatch search order `[ammodepot, dbt_utils, dbt]` configured in `dbt_project.yml`. Zero raw Snowflake/Redshift-specific calls in models.

12. **Silver dedup guards** -- All 55 Fishbowl+Magento Silver models include `QUALIFY ROW_NUMBER()` to prevent duplicate rows from CDC replication.

13. **f_sales incremental merge** -- `f_sales` uses incremental materialization with merge strategy and 3-day lookback window, avoiding full table rebuilds.

---

## Build & Deployment Status

### Redshift (Archived)
- Migrated to Snowflake. Redshift project archived in `archive/projects/ammodepot/`.
- dbt Cloud and MWAA decommissioned.

### Snowflake (Production — ECS Fargate, Iceberg-backed)
- **dbt-core**: 1.11.6 with dbt-snowflake 1.11.2 (ECS image rebuilds may pull newer minor versions, currently 1.11.7 / 1.11.4)
- **Orchestration**: ECS Fargate Spot, every 15 min synced to PBI via EventBridge cron (~$2.50/mo Fargate, replaces dbt Cloud at $663/mo). Cadence dropped from 10 min on 2026-04-28: 96 builds/day vs 144, saves ~$617/mo / ~$7.4K/yr on ETL_WH credits.
- **Last build**: PASS=390, WARN=12, ERROR=0 (104 models + 1 snapshot, ~3.5 min — 2026-04-22). Snapshot fix (PR #18) cleared the persistent ERROR and dropped the `unique_d_customer_segmentation_RANK_ID` WARN permanently via a QUALIFY dedup on `customer_entity_cte`.
- **Previous full build**: PASS=363, WARN=11, ERROR=0 (103 models + 277 tests, ~6 min — 2026-04-07, post-Iceberg-cutover)
- **Build duration**: ~3.5 min steady state (209s). Was ~6 min post-Iceberg; EAV fix (2026-04-08) cut to ~3.2 min; `int_fishbowl_order_cost` Phase A (2026-04-16) saved another ~15s. Current headroom: ~75% of 15-min window (5 min runway before PBI hits).
- **int_fishbowl_order_cost**: Phase A complete (54s → 46s) — eliminated 5th `fishbowl_soitem` scan, removed dead CTE chain, replaced `SELECT f.*`. Phase B (window function rewrite) deferred — monitor PBI cost columns for a few days first.
- **Audit (2026-03-25)**: P0-P3 implemented — parameterized business logic (RFM thresholds, product classification), 40+ new tests, exposures, source freshness, dead code cleanup
- **Dialect fixes applied**: CEILING->CEIL, IS FALSE->= false, varchar/numeric implicit cast, json_extract_text macro
- **Performance optimizations**: Silver dedup guards (QUALIFY), high-fan-out Silver tables, f_sales incremental merge, cross-db dispatch macros
- **Iceberg cutover fixes (2026-04-07)**: NULL-PK guard on `silver/magento/magento_catalog_product_entity.sql` (Iceberg append-only preserves NULL-PK rows that Snowflake MERGE silently dropped); 2-arg `convert_timezone(target, ltz_value)` cast to NTZ in `f_sales`, `int_sales_cost_fallback`, `f_shippment` to preserve PBI's cached datetime schema
- **Storage (2026-03-23)**: AD_AIRBYTE 56.8 GB active + 247 GB failsafe = 304 GB (now read-only since cutover); AD_ANALYTICS 98.3 GB; PC_FIVETRAN_DB 8.8 GB (candidate for drop)

### Streamlit Sales Dashboard (SiS container runtime)

Updated 2026-04-16 — `AD_ANALYTICS.OPS.SALES_DASHBOARD` (5 pages, container runtime):
- Deployed via GitHub Actions (`deploy-streamlit-dashboard.yml`)
- Compute pool: `sales_dashboard_pool` (CPU_X64_XS, 1 node, auto-suspend 300s, ~$5/mo)
- EAI: `sales_dashboard_integration` — CARTO tiles (`basemaps.cartocdn.com`) + PyPI egress
- `--replace` strips EAI on every deploy: CI step re-attaches via `ALTER STREAMLIT SET`
- Full feature parity with local dev: Plotly Scattermap + chart click cross-filtering enabled
- Migrated from `go.Scattermapbox` to `go.Scattermap` (Plotly MapLibre migration)
- Viewers: `DASHBOARD_VIEWER_ROLE` + `POWERBI_READONLY_ROLE` granted USAGE on Streamlit object

### Streamlit Infra Monitor (SiS container runtime)

Renamed 2026-04-15 — `AD_ANALYTICS.OPS.INFRA_MONITOR` (5 pages, container runtime):
- Deployed via GitHub Actions (`deploy-streamlit-cost-monitor.yml`)
- PyPI access: requires `pypi_rule` in EAI (added `04_fix_pypi_access.sql`)
- `--replace` strips EAI on every deploy: CI step re-attaches via `ALTER STREAMLIT SET`
- Container runtime secret mechanism: `_snowflake` module unavailable; env var name undetermined (diagnostic logging active)

### Streamlit Analyst Chatbot (SiS container runtime)

Built 2026-04-14 — `AD_ANALYTICS.OPS.ANALYST` (Cortex Analyst chatbot, container runtime):
- Natural language query interface powered by Snowflake Cortex Analyst + Semantic View (`AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST`)
- Covers 6 Gold tables with 20 verified golden queries; `int_product_analyst` intermediate view resolves D_PRODUCT quoted-column issues
- Deployed via GitHub Actions (`deploy-streamlit-analyst.yml`)
- Shares `sales_dashboard_pool` compute pool (no incremental cost)
- Automated smoke test: `test_golden_questions.py` (25 questions, API + SQL execution validation)

### Demand Forecasting (Cortex ML — Phase 2)

Built 2026-04-14 — 30-day demand predictions by caliber + revenue:
- **ML models**: `CALIBER_FORECAST` (115 calibers, per-SKU time series), `REVENUE_FORECAST` (daily revenue)
- **Training inputs**: `int_daily_sales_by_caliber` + `int_daily_sales_metrics` (2 new dbt intermediate views)
- **Training macro**: `ammodepot/macros/ml_forecast.sql` — `train_caliber_forecast`, `train_revenue_forecast`, `train_all_ml_models`
- **Output table**: `AD_ANALYTICS.GOLD.F_FORECAST` (managed by Snowflake Task, not dbt)
- **Orchestration**: Weekly Task `TASK_DAILY_FORECAST` (Sunday 4am UTC) — retrains models + refreshes predictions
- **Manual view**: `V_DAILY_REVENUE` (used for revenue model training)
- **Visualization**: Page 4 (Forecast) in Sales Dashboard — stock-out risk heatmap, caliber demand charts

### Anomaly Detection (Cortex ML — Phase 3)

Built 2026-04-14 — automated sales anomaly detection:
- **ML models**: `REVENUE_ANOMALY`, `ORDERS_ANOMALY`, `MARGIN_ANOMALY` (3 metrics)
- **Training input**: `int_daily_sales_metrics` (shared with forecasting)
- **Training macro**: `train_anomaly_models` in `ml_forecast.sql`
- **Output table**: `AD_ANALYTICS.GOLD.F_ANOMALIES` (managed by Snowflake Task, not dbt)
- **Alert banner**: Page 1 (Today/Yesterday) shows active anomaly alerts inline
- **Orchestration**: Runs within `TASK_DAILY_FORECAST` weekly cycle

### Customer Churn Narratives (CORTEX.COMPLETE — Phase 4)

Built + Shipped 2026-04-16 — RFM segment health dashboard with LLM executive summary:
- **Page 5**: `5_Customer_Intelligence.py` in Sales Dashboard — segment KPI cards, all 17 classifications table + MoM delta column (from `SNAP_CUSTOMER_SEGMENTATION`), top at-risk customers, `llama3.1-70b` executive summary banner
- **LLM**: `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` — `gemini-2-5-flash` unavailable in this region (400 error); `llama3.1-70b` is native us-east-1. Cached 10 min, graceful fallback.
- **Data**: `D_CUSTOMER_SEGMENTATION` (RFM) — no new dbt models
- **Cost**: ~$0.15/mo (Cortex LLM credits)
- **Archive**: `.claude/sdd/archive/CHURN_NARRATIVES/SHIPPED_2026-04-16.md`

### Inventory Reorder Intelligence (AI Phase 5 — In Progress)

Built 2026-04-16 — prescriptive purchasing recommendations per caliber:
- **New Gold table**: `F_REORDER_RECOMMENDATIONS` — per-caliber REORDER_QTY, URGENCY, RECOMMENDED_VENDOR, ESTIMATED_ORDER_COST. Refreshed every 15 min by ECS dbt build.
- **Formula**: `REORDER_QTY = GREATEST(0, DEMAND_UPPER_30D - QTY_AVAILABLE - QTY_ON_ORDER)` — UPPER_BOUND from F_FORECAST acts as ML-backed safety buffer
- **Vendor**: Lowest avg `PRECISE_LEADTIME` from F_POS per caliber
- **Page 4 tab**: New "Reorder Recommendations" tab in Sales Dashboard Page 4 — LLM brief, 3 KPI cards, urgency filter, reorder table
- **Status**: Shipped 2026-04-16. Validated live: PASS=389, WARN=13, ERROR=0, 103 calibers, 30 Critical ($357K reorder value).
- **Vendor Comparison**: Page 4 "Reorder Recommendations" tab — caliber selector (Critical/Warning only), top 5 vendors by lead time with unit cost + estimated order cost at recommended qty
- **Forecast Accuracy tab**: Page 4 5th tab — EVALUATE() unavailable for multi-series models; "Prediction vs Actual" section compares `F_FORECAST_HISTORY` to actuals (lights up as archived predictions' dates pass, ~7 days to first results)
- **F_FORECAST_HISTORY**: Created 2026-04-16 (3,450 rows, 115 calibers × 30 days). Archived before each weekly retrain. `load_forecast_vs_actual()` joins history to F_SALES for MAE/MAPE/bias/coverage metrics.
- **LLM model**: `llama3.1-70b` (was `gemini-2-5-flash` — unavailable in us-east-1 region, 400 error)
- **Cost**: ~$0.60/mo (Cortex LLM credits, llama3.1-70b)

### Customer Segmentation Snapshot (2026-04-16)

- **Snapshot**: `SNAP_CUSTOMER_SEGMENTATION` in `AD_ANALYTICS.GOLD` — check strategy on `customer_classification`, `frequency`, `recency`, `value`, `margin_classification`
- **Purpose**: Enables MoM segment deltas on Page 5 (Customer Intelligence). First 30 days builds history; MoM column shows `+N`/`-N` per segment after 2026-05-16.
- **Cadence**: Runs after every `dbt build` (every 15 min, non-fatal). `check` strategy means rows only written when classifications change — idempotent.
- **`invalidate_hard_deletes=true`**: Customers dropping out of the 12-month window get `dbt_valid_to` set automatically.
- **Initial population**: 951,760 rows on first run (2026-04-16).

### Snowflake Cost Dashboard (Snowsight)

Built 2026-03-23 — "Snowflake Cost & Usage Monitor" with 8 tiles:
1. Daily Credit Trend (line, by warehouse)
2. Total Credits This Month (scorecard)
3. Credits by Warehouse (bar)
4. Credits by User/Role (bar, proportional allocation)
5. Warehouse Utilization (table)
6. Top Expensive Queries (table)
7. Storage by Database (bar)
8. Cost Anomaly Detection (table)

### S3 Iceberg Lakehouse (Option B — CUTOVER COMPLETE 2026-04-07)

Final architecture: Snowflake reads S3 Iceberg directly. dbt-duckdb evaluated and removed.

```
Airbyte CDC → S3 Iceberg (Glue catalog) → Snowflake LAKEHOUSE_LANDING → dbt Silver/Gold → Power BI
```

- **Motivation**: SVC_AIRBYTE burned 678 credits/mo (74% of total compute)
- **Realized savings**: ~$2,034/mo / **~$24,408/year** — verified via SVC_AIRBYTE credits dropping to ~0/hr after legacy disable
- **Status**: COMPLETE. 55 Iceberg tables active, 4+ consecutive clean dbt builds, 0 errors
- **S3 Bucket**: `ammodepot-lakehouse` (us-east-1, lifecycle rules)
- **Glue Databases**: `production2018` (Fishbowl, 34 tables), `ammuni_prod` (Magento, 21 tables)
- **Snowflake**: External Volume `LAKEHOUSE_S3_VOLUME`, Catalog Integration `LAKEHOUSE_GLUE_CATALOG`
- **IAM**: `svc_airbyte-s3` (S3 + Glue write), `snowflake-lakehouse-role` (S3 + Glue read)
- **Refresh**: dbt `on-run-start` hook calls `ALTER ICEBERG TABLE ... REFRESH` on all 55 (UNMANAGED tables — no auto-refresh)
- **Why Option B over full DuckDB**: DuckDB saved ~$4,152/yr more but added 4 helper scripts, Iceberg write bugs, OOM, 3-4hr initial loads. Option B has near-zero complexity for 85% of the savings.
- **Followups**: Build duration is at ~25% of 15-min schedule (5 min runway before PBI). PBI confirmed empirically as 15-min cadence at :00/:15/:30/:45 (RAFAELA on COMPUTE_WH); secondary low-volume PBI activity on PC_FIVETRAN_WH (POWERBI_AD, ~286 q/wk) — worth auditing whether that schedule should be killed.

---

## Documentation

| Document | Path | Description |
|---|---|---|
| Cost Dashboard | `docs/SNOWFLAKE_COST_DASHBOARD.md` | Snowflake cost monitoring queries, tags, alerts, best practices |
| Lakehouse POC | `docs/POC_S3_DUCKDB_LAKEHOUSE.md` | S3+DuckDB+Iceberg migration plan with step-by-step POC |
| Snowflake Access | `docs/snowflake_access_setup.md` | Role/user/warehouse setup documentation |
| Airbyte 2.0 Upgrade | `docs/AIRBYTE_2_0_UPGRADE_PLAN.md` | Airbyte upgrade procedure, rollback plan, risk assessment |

---

## Agent Usage Guidelines

26 specialized agents in 8 categories (`.claude/agents/`):

| Category | Agents | Use When |
|---|---|---|
| **Data Engineering** | dbt-expert, analytics-engineer, snowflake-expert, medallion-architect, spark-specialist, dagster-expert, lakeflow-architect | dbt models, Snowflake queries, pipeline architecture, Spark jobs, DLT, BI/metrics layer |
| **Code Quality** | code-reviewer, code-documenter, python-developer, test-generator | Reviews, testing, documentation |
| **Communication** | the-planner, adaptive-explainer, meeting-analyst | Planning, stakeholder explanations, meeting notes |
| **DevOps** | ci-cd-specialist | Azure DevOps, Terraform, CI/CD pipelines |
| **Automation** | streamlit-expert | Streamlit apps, SiS deployment, dashboard optimization |
| **Exploration** | codebase-explorer, kb-architect | Codebase analysis, knowledge base management |
| **Workflow** | build-agent, define-agent, design-agent, iterate-agent, ship-agent, brainstorm-agent | SDD pipeline stages |
| **Dev** | prompt-crafter, dev-loop-executor | PROMPT.md creation, Dev Loop execution |

### Most Relevant for This Project

- **dbt-expert** -- dbt model development, testing, and debugging
- **snowflake-expert** -- Snowflake queries, architecture (for migration evaluation)
- **streamlit-expert** -- Streamlit dashboard development, SiS compatibility
- **medallion-architect** -- Bronze/Silver/Gold layer design
- **code-reviewer** -- Post-change code quality review
- **the-planner** -- Multi-step implementation planning

---

## Knowledge Base (616 files / 46 technologies in 6 categories)

| Category | Files | Technologies | Key Technologies |
|---|---|---|---|
| data-engineering | 224 | 16 | dbt-core, dbt-cloud, dagster, snowflake, apache-iceberg, airbyte, duckdb, onehouse, great-expectations, soda, elementary, data-vault, data-contracts, openmetadata, finops, flake8 |
| cloud | 133 | 11 | S3, S3-tables, IAM, Glue, Athena, CloudWatch, KMS, Secrets Manager, Fargate, EMR, GCP |
| devops-sre | 124 | 9 | terraform, terragrunt, kubernetes, docker-compose, grafana, prometheus, uv, github, railway |
| ai-ml | 81 | 6 | pydantic, crewai, langfuse, langflow, gemini, openrouter |
| automation | 38 | 3 | streamlit, n8n, mermaid |
| document-processing | 15 | 1 | docling |

Organized hierarchically under `.claude/kb/`. Snowflake KB includes Cortex Analyst, Semantic Views, Cortex ML Functions, Cortex Code, Interactive Tables, and OpenFlow.

---

## Skills (17 slash commands)

Located in `.claude/skills/<name>/SKILL.md`:

**Core:** `/memory`, `/readme-maker`, `/sync-context`, `/audit`, `/enrich-kb`
**Development:** `/dev`, `/review`, `/create-agent`, `/create-kb`, `/create-skill`
**Workflow (SDD):** `/brainstorm` → `/define` → `/design` → `/build` → `/iterate` → `/ship`, `/create-pr`

---

## Rules

Path-scoped instruction files in `.claude/rules/` (10 files):
- **kb-development.md** — KB file conventions and size limits
- **agent-development.md** — Agent template and MCP validation conventions
- **git-workflow.md** — Commit message and PR conventions
- **sql-standards.md** — SQL coding standards for dbt models
- **dbt-conventions.md** — dbt project conventions and patterns
- **snowflake-standards.md** — Snowflake SQL and architecture standards
- **snowflake-finops-tagging.md** — FinOps: every Snowflake resource must be tagged for cost attribution
- **mermaid-diagrams.md** — Mermaid diagram conventions and rendering
- **skill-development.md** — Skill template and creation conventions
- **ecs-deploy.md** — Auto-deploy to ECS after dbt model changes (scoped to ammodepot/, ecs/)

---

## Delivery Standards (5 documents in `.claude/docs/`)

trinityBI Engineering delivery standards that apply across all client projects:

| Doc | Scope |
|-----|-------|
| `01_NEW_PROJECT_CHECKLIST.md` | New project onboarding checklist |
| `04_GIT_AND_WORKFLOW.md` | Git branching, commit, and PR workflow standards |
| `05_DBT_DATA_PRACTICE_STANDARDS.md` | dbt project layout, modeling, and testing standards |
| `06_SNOWFLAKE_RBAC_STANDARDS.md` | Snowflake role/user/warehouse naming and grant patterns |
| `07_MODEL_SELECTION_POLICY.md` | Claude model selection policy (Haiku/Sonnet/Opus) |

---

## MCP Tools Available

| MCP Server | Purpose |
|---|---|
| context7 | Library documentation lookup |
| exa | Code context search (web) |
| Ref | Framework documentation |
| upstash-context-7-mcp | KB context storage and retrieval |
