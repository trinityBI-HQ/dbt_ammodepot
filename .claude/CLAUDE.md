# ammodepot

## Project Context

dbt project for Ammunition Depot's analytics pipeline. Transforms raw data from Fishbowl (inventory/ERP) and Magento (e-commerce) into structured, tested datasets using Medallion Architecture.

Data is ingested via Airbyte CDC, then transformed through Bronze, Silver, and Gold layers.

### Warehouse Migration (Complete)

Migrated from **Amazon Redshift** to **Snowflake**. Redshift project archived.
- **Snowflake** (`ammodepot/`): Production — 99 models, ECS Fargate orchestration every 10 min
- **Redshift** (`archive/projects/ammodepot/`): Archived — no longer running
- **Adapter**: dbt-snowflake 1.11.3

### Snowflake Database Architecture

```
AD_AIRBYTE (AIRBYTE_ROLE)          AD_ANALYTICS (TRANSFORMER_ROLE)
├── AD_FISHBOWL (34 streams)       ├── SILVER (71 views + 7 tables)
├── AD_MAGENTO (29 streams)         └── GOLD (13 tables + 8 views)
└── airbyte_internal                     ↑ Power BI reads here
```

- **Roles**: `AIRBYTE_ROLE` (ingestion), `TRANSFORMER_ROLE` (dbt), `POWERBI_ROLE` (read-only BI), `POWERBI_READONLY_ROLE` (Gold + Streamlit viewer), `STREAMLIT_ROLE` (app owner), `DASHBOARD_VIEWER_ROLE` (SSO viewers)
- **Service accounts**: `SVC_AIRBYTE` (key-pair), `SVC_DBT` (key-pair), `SVC_POWERBI` (password), `POWERBI_READER` (password, POWERBI_READONLY_ROLE)
- **Warehouse**: `ETL_WH` (XSMALL, auto-suspend 60s, shared by Airbyte + dbt; BI roles to be migrated to dedicated `BI_WH`)
- **Legacy warehouses** (to be suspended): `PC_FIVETRAN_WH` ($540/mo), `COMPUTE_WH` ($46/mo)
- **Query tags**: All users tagged via `QUERY_TAG` for cost attribution
- **Cost optimization**: ~$847/mo confirmed savings (dbt Cloud, EC2 downsize, MWAA); ~$1,433/mo potential with legacy warehouse suspension

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
| Transformation | dbt-core 1.11.6 + dbt-redshift 1.10.1 / dbt-snowflake 1.11.2 |
| Warehouse | Amazon Redshift (production) + Snowflake (migration target) |
| Ingestion | Airbyte CDC (6 active connections, 141 streams) |
| Orchestration | ECS Fargate Spot (every 10 min) + EventBridge scheduler |
| Packages | dbt_utils, dbt_expectations (metaplane fork) |
| Cross-db macros | `adapter.dispatch` for `json_extract_text`, `convert_tz`, `string_agg`, `format_timestamp` |
| Linting | SQLFluff (Redshift dialect / Snowflake dialect) |
| Python | uv (package manager) |
| BI Dashboard | Streamlit (local + Streamlit in Snowflake) |
| EC2 Maintenance | Bash scripts (cron-scheduled cleanup + disk alerts) |
| Archive | Decommissioned configs (MWAA DAGs, old artifacts) |

---

## Streamlit Dashboard App

Replacement for Power BI dashboards, running locally and targeting Streamlit in Snowflake (SiS).

```
streamlit_app/
├── app.py                         # Entry point (local) (~38 lines)
├── streamlit_app.py               # Entry point (SiS) (~32 lines)
├── pages/
│   ├── 1_Today_Yesterday.py       # Real-time sales + cross-filtering (replaces PBI SALES OVERVIEW FASTER) ~1,380 lines
│   ├── 2_Sales_Overview.py        # Historical sales with category pages + cross-filtering (replaces PBI SALES OVERVIEW) ~1,529 lines
│   └── 3_Inventory.py             # Inventory + Vendor Analysis + Open POs (replaces PBI INVENTORY) ~1,272 lines
└── utils/
    ├── __init__.py
    ├── chart_theme.py             # Unified dark theme for Plotly charts + HTML tables (~127 lines)
    ├── db.py                      # Query runner, _is_sis flag, numeric/timestamp coercion (~155 lines)
    └── zip3_coords.py             # 886-entry ZIP3→(lat,lon) centroid lookup for maps (~307 lines)
```

**Total:** ~4,840 lines across 9 Python files

### Cross-Filtering (PBI-style)

Pages 1 and 2 implement PBI-style cross-filtering with selectbox dropdowns + clickable Plotly charts:
- **Session state keys**: `ty_xf_cat`, `ty_xf_mfr`, `ty_xf_vendor`, `ty_xf_sku`, `ty_xf_cust` (Today/Yesterday) and `so_xf_mfr`, `so_xf_vendor`, `so_xf_sku`, `so_xf_cust` (Sales Overview)
- **Pending-state pattern**: Chart clicks store `(key, value)` in `_ty_xf_pending`/`_so_xf_pending`, consumed before widget rendering on next rerun
- **`on_click` callback**: Clear All button uses `st.button(on_click=fn)` — avoids `StreamlitAPIException` from setting widget keys after instantiation
- **Active filter pills**: HTML spans with colored badges showing current filters
- **Bar dimming**: Non-selected Plotly bars render at 20% opacity when a filter is active
- **Clickable charts**: Local only — SiS older Streamlit returns `event.selection` as callable, guarded with `_is_sis`
- **Dropdown options**: Built from pre-filter data (PBI behavior — show all values regardless of active filters)

### Dark Theme Architecture

All visual components force a unified dark background (`#1E1E1E`) via `utils/chart_theme.py`:
- **`apply_theme(fig)`**: Forces dark `plot_bgcolor`/`paper_bgcolor`, light text, subtle grid on all Plotly `go.Figure` charts
- **`dark_dataframe(df)`**: Renders DataFrames as dark HTML tables via `st.markdown` — replaces all `st.dataframe` calls (SiS iframe can't be styled with external CSS)
- **`secondary_axis_style()`**: Returns color + tickfont dict for yaxis2
- **Inventory HTML bars**: Wrapped in `<div style="background:#1E1E1E">` containers with light text
- **Constants**: `BG_CHART`, `ACCENT`, `TEXT_PRIMARY`, `TEXT_SECONDARY`, `GRID_COLOR` shared across all pages

### SiS Compatibility Notes

- **Runtime**: Currently "Run on warehouse" (Streamlit 1.22, limited); migration target is "Run on container" (Streamlit 1.50+, PREVIEW)
- **Plotly**: Use `go.Bar`/`go.Figure` with `.tolist()` — `px.bar` fails serialization in SiS
- **Plotly x-axis**: Use numeric positions + `tickvals`/`ticktext` to avoid duplicate category merging
- **Plotly on_select**: Guard with `if not _is_sis:` — SiS returns `event.selection` as a function, not data object
- **Maps**: Scattermapbox (local only, CARTO tiles blocked in SiS), `st.map()` fallback for SiS
- **Data types**: All plotly data must be plain Python types (`float()`, `.tolist()`), not numpy/pandas
- **Dual-mode**: `_is_sis` flag in `utils/db.py` controls local vs SiS rendering paths
- **st.toggle**: Not available in SiS (Python 3.11) — use `st.checkbox` instead
- **st.dataframe**: Renders inside iframe that ignores external CSS on SiS — use `dark_dataframe()` instead
- **Theme detection**: `st.get_option("theme.base")` unreliable on SiS — force dark backgrounds explicitly
- **Session state pattern**: Initialize defaults in `st.session_state`, render widgets with `key=` only (no `value=`)
- **Full-width CSS**: All pages inject CSS to remove Streamlit default max-width padding
- **PBI data filters**: Vendor Analysis + Open POs filter to `Ammunition` category + `QTY != 0` (matches PBI)
- **KPI cards**: Custom HTML/CSS with `st.markdown(unsafe_allow_html=True)` — PBI-style icons, colored borders
- **Default filters**: Order Status preselected to COMPLETE, PROCESSING, UNVERIFIED (matches PBI)

---

## Project Structure

### Snowflake Project (Production)

```
ammodepot/
├── dbt_project.yml             # version 2.0
├── packages.yml
├── profiles.yml                # Not committed (.gitignore)
├── .env                        # Not committed (.gitignore)
├── .env.example                # Snowflake-only connection vars
├── .sqlfluff                   # dialect: snowflake
├── macros/
│   ├── generate_schema_name.sql
│   ├── json_extract_text.sql   # Cross-dialect JSON extraction (adapter.dispatch)
│   └── cross_db/               # Cross-dialect dispatch macros
│       ├── convert_tz.sql
│       ├── string_agg.sql
│       └── format_timestamp.sql
├── tests/generic/              # 16 custom generic tests (same as Redshift)
├── models/
│   ├── bronze/                 # Source definitions (reads from AD_AIRBYTE database)
│   │   ├── fishbowl/           # schema: AD_FISHBOWL (34 source tables)
│   │   └── magento/            # schema: AD_MAGENTO (25 source tables)
│   ├── silver/                 # 78 models (71 views + 7 high-fan-out tables)
│   └── gold/                   # 13 table models + 8 intermediate views
│       ├── intermediate/       # 8 reusable view models (includes int_sales_cost_fallback)
│       ├── (all Redshift gold models)
│       ├── f_cohort.sql        # NEW: Customer cohort analysis
│       ├── f_cohort_detailed.sql  # NEW: Detailed cohort metrics
│       └── f_sales_realtime.sql   # NEW: Real-time sales view
├── seeds/
├── snapshots/
└── analyses/
```

**Snowflake Counts:** 99 models (34 FB + 23 MG + 21 Inv + 13 Gold + 8 Int), 59 source tables, 16 generic tests, 5 macros (2 root + 3 cross_db)

### Streamlit App (BI Dashboard)

```
streamlit_app/                          # See "Streamlit Dashboard App" section above
```

### Airbyte EC2 Maintenance Scripts

```
airbyte-ec2/
├── airbyte-cleanup.sh      # Monthly cleanup: Minio logs + DB pruning + VACUUM (~123 lines)
├── disk-alert.sh           # 6-hourly disk usage alert to log (~43 lines)
└── deploy.sh               # One-command installer for EC2 (~76 lines)
```

- **Deployed to**: `/opt/scripts/` on EC2 instance `ip-10-0-1-105`
- **Cron**: Monthly cleanup (1st at 3am UTC), disk alert (every 6h)
- **Logs**: `/var/log/airbyte-cleanup.log`, `/var/log/disk-alert.log`
- **Dry run**: `sudo /opt/scripts/airbyte-cleanup.sh --dry-run`
- **Docs**: `docs/AIRBYTE_MAINTENANCE.md`

### ECS Fargate (dbt Orchestration)

```
ecs/
├── Dockerfile                 # Python 3.11-slim + uv + dbt-snowflake (~40s build)
├── entrypoint.sh              # Writes RSA key from env, runs dbt build --target prod
├── pyproject.toml             # Minimal deps: dbt-core + dbt-snowflake
├── task-definition.json       # 0.5 vCPU, 1 GB, Secrets Manager refs
├── eventbridge-rule.json      # rate(10 minutes) trigger
├── iam-policies/              # Least-privilege IAM role policies
│   ├── task-execution-trust.json
│   ├── task-execution-role.json
│   ├── eventbridge-trust.json
│   └── eventbridge-role.json
└── README.md                  # Full deployment guide
```

- **Cluster**: `ammodepot-dbt` (Fargate Spot, us-east-1)
- **Task**: `ammodepot-dbt-build` (0.5 vCPU, 1 GB, ~3 min/run)
- **Schedule**: EventBridge `rate(10 minutes)`
- **Network**: Private subnets in airbyte-project VPC
- **Secrets**: `ammodepot/dbt/snowflake` (Secrets Manager — RSA key + passphrase)
- **Logs**: CloudWatch `/ecs/ammodepot-dbt`
- **Monitoring**: CloudWatch dashboard `ammodepot-dbt` (build results, duration, warnings, errors)
- **Alerts**: `dbt-build-failure` (ERROR in logs), `dbt-task-missing` (no runs in 30 min) → SNS email
- **Cost**: ~$3.70/month total (replaces dbt Cloud at $663/mo)
- **ECR**: `746669199691.dkr.ecr.us-east-1.amazonaws.com/ammodepot/dbt`
- **AWS CLI user**: `svc_iac` (ADBIadmin group, CLI-only)

### Archive (Decommissioned)

```
archive/
├── mwaa/                              # MWAA DAGs + config (deleted 2026-03-23, ~$450/mo saved)
├── projects/ammodepot/                # Redshift dbt project (migrated to Snowflake)
└── target/                            # Old dbt build artifacts
```

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

### Magento (25 tables both projects, 29 Airbyte streams)
E-commerce platform. Key tables: `sales_order`, `sales_order_item`, `customer_entity`, `catalog_product_entity`, `quote`, `store`, EAV attribute tables (`eav_attribute`, `catalog_product_entity_varchar/int/text/decimal`)
- Redshift: `magento` schema | Snowflake: `AD_AIRBYTE.AD_MAGENTO`

### Source Freshness
Both sources have freshness configured: warn after 24h, error after 48h, using `_airbyte_extracted_at` as the loaded_at_field.

### Airbyte Connections (6 active, updated 2026-03-07)

| # | Connection | Dest | Frequency | Streams | Sync Mode |
|---|---|---|---|---|---|
| 1 | Fishbowl → Redshift | RS | Hourly | 21 | All Incremental+Dedup |
| 2 | Fishbowl → Redshift (Low Frequency) | RS | Hourly+7min | 16 | All Full Refresh+Overwrite |
| 3 | Fishbowl → Snowflake | SF | 10 min | 35 | 33 Incremental + 2 FR (`tagserialview`, `upsview_ad_a`) |
| 4 | Magento → Snowflake | SF | 10 min | 29 | All Incremental+Dedup |
| 5 | Magento → Redshift | RS | Hourly | 39 | All Incremental+Dedup |
| 6 | Snowflake → Redshift | RS | Daily | 1 | FR (`UPS_INVOICE` from UPS_INVOICE_HISTORY) |

- **Full audit**: `Connections Audit - Ammo Depot.xlsx` (per-stream detail)
- **Deleted**: FB→RS (so+soitem), MGT→RS (SALES), MGT→RS (CATALOG) — merged into main connections

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

---

## Key Design Decisions

1. **Airbyte CDC over Fivetran** -- Sources use `_ab_cdc_deleted_at` and `_ab_cdc_updated_at` columns for change tracking.

2. **Bronze = source definitions only** -- ammodepot's Bronze layer is purely YAML source definitions. Airbyte loads directly into `fishbowl.*` and `magento.*` schemas.

3. **Silver views, Gold tables** -- Silver is lightweight (views) for real-time freshness, with 7 high-fan-out models overridden to tables (fishbowl_soitem, fishbowl_product, fishbowl_uomconversion, fishbowl_part, magento_sales_order_item, magento_sales_order, inventory_qtyinventorytotals). Gold materializes as tables for BI query performance.

4. **Intermediate views in Gold schema** -- Complex CTEs extracted from `f_sales` and `d_product` into 8 reusable intermediate views, materialized in the `gold` schema. Includes `int_sales_cost_fallback` (cost fallback logic extracted from f_sales) and `int_magento_product_eav_lookups` (single-scan pivot for EAV resolution).

5. **UPPER_CASE gold columns** -- Gold layer output uses UPPER_CASE aliases for backward compatibility with existing Power BI consumers.

6. **EAV attribute parameterization** -- Magento attribute IDs are configured as dbt variables to avoid hardcoding numeric IDs in SQL.

7. **All config centralized** -- Model materialization and schema routing defined in `dbt_project.yml`, not in per-model config blocks.

8. **Generic tests in `tests/generic/`** -- 16 reusable test macros using `{% test %}` wrapper syntax.

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

### Snowflake (Production — ECS Fargate)
- **dbt-core**: 1.11.7 with dbt-snowflake 1.11.3
- **Orchestration**: ECS Fargate Spot, every 10 min via EventBridge (~$3.70/mo, replaces dbt Cloud at $663/mo)
- **Last build**: PASS=430, WARN=9, ERROR=0 (99 models + 340 tests, ~3 min — 2026-03-23)
- **Dialect fixes applied**: CEILING->CEIL, IS FALSE->= false, varchar/numeric implicit cast, json_extract_text macro
- **Performance optimizations**: Silver dedup guards (QUALIFY), high-fan-out Silver tables, f_sales incremental merge, cross-db dispatch macros
- **Data quality fixes (2026-03-20)**: taxonomy dedup, qohview ghost tag filter, test severity promotions
- **Reverted (2026-03-20)**: d_store admin row (Magento already includes store_id=0 natively)

---

## Agent Usage Guidelines

44 specialized agents organized by category in `.claude/agents/`:

| Category | Agents | Use When |
|---|---|---|
| **Data Engineering** | dbt-expert, snowflake-expert, medallion-architect, spark-specialist, spark-performance-analyzer, spark-troubleshooter, spark-streaming-architect, dagster-expert | dbt models, Snowflake queries, pipeline architecture, Spark jobs |
| **Databricks** | lakeflow-expert, lakeflow-architect, lakeflow-pipeline-builder | DLT pipelines, Lakeflow CDC, DABs deployment |
| **AI/ML** | extraction-specialist, genai-architect, dataops-builder, ai-data-engineer, ai-prompt-specialist, llm-specialist | LLM prompts, extraction, multi-agent systems |
| **Cloud - AWS** | lambda-builder, aws-deployer, aws-lambda-architect | Lambda functions, SAM templates, S3 triggers |
| **Cloud - GCP** | function-developer, pipeline-architect, infra-deployer | Cloud Run, Pub/Sub, Terraform/Terragrunt |
| **Code Quality** | code-reviewer, code-cleaner, code-documenter, dual-reviewer, python-developer, test-generator | Reviews, refactoring, testing, documentation |
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

## Knowledge Base (604 files in 6 categories)

| Category | Files | Key Technologies |
|---|---|---|
| data-engineering | 213 | dbt-core, dbt-cloud, dagster, snowflake, iceberg, great-expectations, DuckDB, elementary |
| cloud | 132 | S3, IAM, Glue, Athena, CloudWatch, KMS, GCP, EMR, Fargate |
| devops-sre | 124 | terraform, terragrunt, kubernetes, docker-compose, grafana, prometheus, uv, github |
| ai-ml | 81 | pydantic, crewai, langfuse, langflow, gemini, openrouter |
| automation | 38 | mermaid, n8n, Streamlit |
| document-processing | 15 | docling |

Organized hierarchically under `.claude/kb/`. Snowflake KB includes Cortex Code, Interactive Tables, and OpenFlow.

---

## Skills (14 slash commands)

Located in `.claude/skills/<name>/SKILL.md`:

**Core:** `/memory`, `/readme-maker`, `/sync-context`
**Development:** `/dev`, `/review`, `/create-agent`, `/create-kb`
**Workflow (SDD):** `/brainstorm` → `/define` → `/design` → `/build` → `/iterate` → `/ship`, `/create-pr`

---

## Rules

Path-scoped instruction files in `.claude/rules/`:
- **kb-development.md** — KB file conventions and size limits
- **agent-development.md** — Agent template and MCP validation conventions
- **git-workflow.md** — Commit message and PR conventions
- **sql-standards.md** — SQL coding standards for dbt models

---

## MCP Tools Available

| MCP Server | Purpose |
|---|---|
| context7 | Library documentation lookup |
| exa | Code context search (web) |
| Ref | Framework documentation |
| upstash-context-7-mcp | KB context storage and retrieval |
