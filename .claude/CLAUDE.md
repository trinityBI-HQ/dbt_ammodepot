# ammodepot

## Project Context

dbt project for Ammunition Depot's analytics pipeline. Transforms raw data from Fishbowl (inventory/ERP) and Magento (e-commerce) into structured, tested datasets using Medallion Architecture.

Data is ingested via Airbyte CDC, then transformed through Bronze, Silver, and Gold layers.

### Warehouse Migration (In Progress)

Migrating from **Amazon Redshift** to **Snowflake**. Two parallel dbt projects:
- **Redshift** (`projects/ammodepot/`): Production — dbt Cloud scheduled runs, 95 models
- **Snowflake** (`ammodepot/`): Operational — 98 models, all passing (3 new Gold models)
- **Setup guide**: `docs/snowflake_access_setup.md` (roles, warehouses, RSA keys, Power BI access)
- **Pipeline assessment**: `docs/PIPELINE_ASSESSMENT.md` (end-to-end audit, 6 Airbyte connections)
- **Power BI migration**: `docs/POWERBI_MIGRATION_PLAN.md` (3-phase plan: source swap → consolidate → retire)
- **Adapters**: dbt-redshift 1.10.1 (Redshift) + dbt-snowflake 1.11.2 (Snowflake)

### Snowflake Database Architecture

```
AD_AIRBYTE (AIRBYTE_ROLE)          AD_ANALYTICS (TRANSFORMER_ROLE)
├── AD_FISHBOWL (35 streams)       ├── SILVER (78 views)
├── AD_MAGENTO (29 streams)         └── GOLD (13 tables + 7 views)
└── airbyte_internal                     ↑ Power BI reads here
```

- **Roles**: `AIRBYTE_ROLE` (ingestion), `TRANSFORMER_ROLE` (dbt), `POWERBI_ROLE` (read-only BI)
- **Service accounts**: `SVC_AIRBYTE` (key-pair), `SVC_DBT` (key-pair), `SVC_POWERBI` (password)
- **Warehouse**: `ETL_WH` (XSMALL, shared by all three roles)

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
| Packages | dbt_utils, dbt_expectations (metaplane fork) |
| Linting | SQLFluff (Redshift dialect / Snowflake dialect) |
| Python | uv (package manager) |
| BI Dashboard | Streamlit (local + Streamlit in Snowflake) |

---

## Streamlit Dashboard App

Replacement for Power BI dashboards, running locally and targeting Streamlit in Snowflake (SiS).

```
streamlit_app/
├── app.py                         # Entry point (local)
├── streamlit_app.py               # Entry point (SiS)
├── pages/
│   ├── 1_Today_Yesterday.py       # Real-time sales (replaces PBI SALES OVERVIEW FASTER) ~958 lines
│   ├── 2_Sales_Overview.py        # Historical sales with category pages (replaces PBI SALES OVERVIEW) ~1,090 lines
│   └── 3_Inventory.py             # Inventory + Vendor Analysis + Open POs (replaces PBI INVENTORY) ~1,356 lines
└── utils/
    ├── db.py                      # Query runner, _is_sis flag, numeric/timestamp coercion
    └── zip3_coords.py             # 886-entry ZIP3→(lat,lon) centroid lookup for maps
```

**Total:** ~3,936 lines across 8 Python files

### SiS Compatibility Notes

- **Plotly**: Use `go.Bar`/`go.Figure` with `.tolist()` — `px.bar` fails serialization in SiS
- **Plotly x-axis**: Use numeric positions + `tickvals`/`ticktext` to avoid duplicate category merging
- **Maps**: Scattermapbox (local only, CARTO tiles blocked in SiS), `st.map()` fallback for SiS
- **Data types**: All plotly data must be plain Python types (`float()`, `.tolist()`), not numpy/pandas
- **Dual-mode**: `_is_sis` flag in `utils/db.py` controls local vs SiS rendering paths
- **st.toggle**: Not available in SiS (Python 3.11) — use `st.checkbox` instead
- **Session state pattern**: Initialize defaults in `st.session_state`, render widgets with `key=` only (no `value=`)
- **Full-width CSS**: All pages inject CSS to remove Streamlit default max-width padding
- **PBI data filters**: Vendor Analysis + Open POs filter to `Ammunition` category + `QTY != 0` (matches PBI)
- **KPI cards**: Custom HTML/CSS with `st.markdown(unsafe_allow_html=True)` — PBI-style icons, colored borders
- **Default filters**: Order Status preselected to COMPLETE, PROCESSING, UNVERIFIED (matches PBI)

---

## Project Structure

### Redshift Project (Production)

```
projects/ammodepot/
├── dbt_project.yml             # version 1.0
├── packages.yml
├── profiles.yml                # Not committed (.gitignore)
├── .env                        # Not committed (.gitignore)
├── .env.example                # Snowflake + Redshift connection vars
├── .sqlfluff                   # dialect: redshift
├── macros/
│   └── generate_schema_name.sql
├── tests/generic/              # 16 custom generic tests
├── models/
│   ├── bronze/                 # Source definitions only
│   │   ├── fishbowl/           # 34 source tables
│   │   └── magento/            # 25 source tables
│   ├── silver/                 # 78 view models
│   │   ├── fishbowl/           # 34 models (ERP data)
│   │   ├── magento/            # 23 models (e-commerce data)
│   │   └── inventory/          # 21 models (quantity calculations)
│   └── gold/                   # 10 table models + 7 intermediate views
│       ├── intermediate/       # 7 reusable view models
│       ├── d_customer.sql, d_customer_segmentation.sql, d_product.sql
│       ├── d_product_bundle.sql, d_store.sql, d_vendor.sql
│       ├── f_inventoryview.sql, f_pos.sql, f_sales.sql
│       └── f_shippment.sql
├── seeds/
├── snapshots/
└── analyses/
```

**Redshift Counts:** 95 models (34 FB + 23 MG + 21 Inv + 10 Gold + 7 Int), 59 source tables, 16 generic tests, 1 macro

### Snowflake Project (Migration Target)

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
│   └── json_extract_text.sql   # Cross-dialect JSON extraction macro
├── tests/generic/              # 16 custom generic tests (same as Redshift)
├── models/
│   ├── bronze/                 # Source definitions (reads from AD_AIRBYTE database)
│   │   ├── fishbowl/           # schema: AD_FISHBOWL (35 source tables)
│   │   └── magento/            # schema: AD_MAGENTO (30 source tables)
│   ├── silver/                 # 78 view models (same as Redshift)
│   └── gold/                   # 13 table models + 7 intermediate views
│       ├── intermediate/       # 7 reusable view models (same as Redshift)
│       ├── (all Redshift gold models)
│       ├── f_cohort.sql        # NEW: Customer cohort analysis
│       ├── f_cohort_detailed.sql  # NEW: Detailed cohort metrics
│       └── f_sales_realtime.sql   # NEW: Real-time sales view
├── seeds/
├── snapshots/
└── analyses/
```

**Snowflake Counts:** 98 models (34 FB + 23 MG + 21 Inv + 13 Gold + 7 Int), 65 source tables, 16 generic tests, 2 macros

### Streamlit App (BI Dashboard)

```
streamlit_app/                          # See "Streamlit Dashboard App" section above
```

### Shared Documentation

```
docs/
├── snowflake_access_setup.md          # Snowflake roles, warehouses, RSA keys, Power BI access, temp users
├── POWERBI_MIGRATION_PLAN.md          # 3-phase Power BI migration: Redshift → Snowflake AD_ANALYTICS.GOLD
├── PIPELINE_ASSESSMENT.md             # End-to-end pipeline audit (Airbyte, Power BI, dbt)
├── AIRBYTE_MAINTENANCE.md             # EC2/Kind maintenance, cleanup scripts, emergency recovery
└── CONSOLIDATION_EXECUTIVE_SUMMARY.md # Project consolidation summary
DISCOVERY_POWERBI.md                   # (root) Power BI dataflow-to-source mapping
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
| Silver | `view` | Lightweight, real-time freshness |
| Gold | `table` | Consumption-ready for BI tools |
| Intermediate | `view` | Reusable pre-computation for Gold tables |

### Schema Routing

`generate_schema_name` macro routes schemas:
- **Production** (`target.name == 'prod'`): Uses layer schemas (`silver`, `gold`)
- **Development**: All models in `target.schema` (e.g. `dbt_dev`) for isolation

---

## Sources

### Fishbowl (34 Redshift / 35 Snowflake tables)
Inventory management / ERP system. Key tables: `so`, `soitem`, `product`, `part`, `vendor`, `ship`, `po`, `poitem`, `receipt`, `receiptitem`, `uomconversion`, `kititem`, `objecttoobject`
- Redshift: `fishbowl` schema | Snowflake: `AD_AIRBYTE.AD_FISHBOWL`

### Magento (25 Redshift / 30 Snowflake source tables, 29 Airbyte streams)
E-commerce platform. Key tables: `sales_order`, `sales_order_item`, `customer_entity`, `catalog_product_entity`, `quote`, `store`, EAV attribute tables (`eav_attribute`, `catalog_product_entity_varchar/int/text/decimal`)
- Redshift: `magento` schema | Snowflake: `AD_AIRBYTE.AD_MAGENTO`

### Source Freshness
Both sources have freshness configured: warn after 24h, error after 48h, using `_airbyte_extracted_at` as the loaded_at_field.

### Airbyte Connections (6 active, updated 2026-03-07)

| # | Connection | Dest | Frequency | Streams | Sync Mode |
|---|---|---|---|---|---|
| 1 | Fishbowl → Redshift | RS | Hourly | 21 | All Incremental+Dedup |
| 2 | Fishbowl → Redshift (Low Frequency) | RS | Hourly+7min | 16 | All Full Refresh+Overwrite |
| 3 | Fishbowl → Snowflake | SF | 5 min | 35 | 33 Incremental + 2 FR (`tagserialview`, `upsview_ad_a`) |
| 4 | Magento → Snowflake | SF | 5 min | 29 | All Incremental+Dedup |
| 5 | Magento → Redshift | RS | Hourly | 39 | All Incremental+Dedup |
| 6 | Snowflake → Redshift | RS | Daily | 1 | FR (`UPS_INVOICE` from UPS_INVOICE_HISTORY) |

- **Full audit**: `Connections Audit - Ammo Depot.xlsx` (per-stream detail)
- **Deleted**: FB→RS (so+soitem), MGT→RS (SALES), MGT→RS (CATALOG) — merged into main connections

### EAV Pattern
Magento uses Entity-Attribute-Value for product attributes. Product attributes are resolved in `int_magento_product_eav_lookups.sql` and `int_magento_product_attributes.sql`, then consumed by `d_product.sql`. Attribute IDs are configured as dbt variables with prefix `ammodepot_magento_attr_id_*`.

---

## Common Commands

### Redshift Project (from `projects/ammodepot/`)

```bash
uv run dbt deps --profiles-dir .           # Install packages
uv run dbt debug --profiles-dir .          # Test connection
uv run dbt parse --profiles-dir .          # Validate SQL/YAML (no connection needed)
uv run dbt build --profiles-dir .          # Run all models + tests
uv run dbt build --profiles-dir . --select +f_sales   # Run f_sales with upstream deps
uv run dbt test --profiles-dir . --select gold        # Test gold layer only
uv run dbt source freshness --profiles-dir .          # Check source freshness
uv run sqlfluff lint models/               # Lint all models
uv run sqlfluff fix models/                # Auto-fix (review changes before committing)
```

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

3. **Silver views, Gold tables** -- Silver is lightweight (views) for real-time freshness. Gold materializes as tables for BI query performance.

4. **Intermediate views in Gold schema** -- Complex CTEs extracted from `f_sales` and `d_product` into 7 reusable intermediate views, materialized in the `gold` schema.

5. **UPPER_CASE gold columns** -- Gold layer output uses UPPER_CASE aliases for backward compatibility with existing Power BI consumers.

6. **EAV attribute parameterization** -- Magento attribute IDs are configured as dbt variables to avoid hardcoding numeric IDs in SQL.

7. **All config centralized** -- Model materialization and schema routing defined in `dbt_project.yml`, not in per-model config blocks.

8. **Generic tests in `tests/generic/`** -- 16 reusable test macros using `{% test %}` wrapper syntax.

9. **Snowflake migration** -- Separate Snowflake dbt project (`ammodepot/`) with 3 new Gold models (f_cohort, f_cohort_detailed, f_sales_realtime). `AD_AIRBYTE` database for sources (AD_FISHBOWL/AD_MAGENTO schemas), `AD_ANALYTICS` database for Silver/Gold output. Three roles: `TRANSFORMER_ROLE` (dbt), `AIRBYTE_ROLE` (ingestion), `POWERBI_ROLE` (read-only BI). Power BI migration plan in `docs/POWERBI_MIGRATION_PLAN.md`. Cross-dialect `json_extract_text` macro handles Snowflake vs Redshift JSON syntax.

10. **No column removals/renames without Power BI coordination** -- Gold layer tables are consumed directly by Power BI dashboards. Any column removal, rename, or type change requires coordinated BI update. See `docs/PIPELINE_ASSESSMENT.md` for pipeline details.

---

## Build & Deployment Status

### Redshift (Production)
- **dbt-core**: 1.11.6 with dbt-redshift 1.10.1
- **dbt Cloud**: Scheduled runs, 88 of 95 models selected
- **Last local build**: PASS=402, WARN=32, ERROR=0, SKIP=0, TOTAL=434
- **Audit score**: 8.0/10

### Snowflake (Migration Target)
- **dbt-core**: 1.11.6 with dbt-snowflake 1.11.2
- **Last build**: PASS=426, WARN=12, ERROR=0, SKIP=0, TOTAL=438 (98 models, 340 tests)
- **Dialect fixes applied**: CEILING->CEIL, IS FALSE->= false, varchar/numeric implicit cast, json_extract_text macro

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

## Knowledge Base (537 files in 6 categories)

| Category | Files | Key Technologies |
|---|---|---|
| data-engineering | 190 | dbt-core, dbt-cloud, dagster, snowflake, iceberg, great-expectations, DuckDB, elementary |
| cloud | 117 | S3, IAM, Glue, Athena, CloudWatch, KMS, GCP, EMR, Fargate |
| devops-sre | 110 | terraform, terragrunt, kubernetes, docker-compose, grafana, prometheus, uv, github |
| ai-ml | 74 | pydantic, crewai, langfuse, langflow, gemini, openrouter |
| automation | 33 | mermaid, n8n, Streamlit |
| document-processing | 13 | docling |

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

---

## MCP Tools Available

| MCP Server | Purpose |
|---|---|
| context7 | Library documentation lookup |
| exa | Code context search (web) |
| Ref | Framework documentation |
| upstash-context-7-mcp | KB context storage and retrieval |
