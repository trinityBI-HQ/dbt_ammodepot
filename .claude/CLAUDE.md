# ammodepot

## Project Context

dbt project for Ammunition Depot's analytics pipeline. Transforms raw data from Fishbowl (inventory/ERP) and Magento (e-commerce) into structured, tested datasets using Medallion Architecture.

Data is ingested via Airbyte CDC, then transformed through Bronze, Silver, and Gold layers.

### Warehouse Migration (In Progress)

Migrating from **Amazon Redshift** to **Snowflake**. Current state:
- **Redshift**: Production (dbt models run here today)
- **Snowflake**: Setting up — Airbyte destination, service accounts, key-pair auth
- **Setup guide**: `docs/snowflake_access_setup.md` (roles, warehouses, RSA keys)
- **Adapter switch**: dbt-redshift installed; dbt-snowflake pending
- Both connection configs in `.env.example` (Snowflake + Redshift)

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
| Transformation | dbt-core + dbt-redshift (migrating to dbt-snowflake) |
| Warehouse | Amazon Redshift (migrating to Snowflake) |
| Ingestion | Airbyte (CDC) |
| Packages | dbt_utils, dbt_expectations (metaplane fork) |
| Linting | SQLFluff (Redshift dialect) |
| Python | uv (package manager) |

---

## Project Structure

```
projects/ammodepot/
├── dbt_project.yml
├── packages.yml
├── profiles.yml              # Not committed (.gitignore)
├── .env                      # Not committed (.gitignore)
├── .env.example              # Snowflake + Redshift connection vars
├── .sqlfluff
├── macros/
│   └── generate_schema_name.sql
├── tests/generic/            # 16 custom generic tests
├── models/
│   ├── bronze/               # Source definitions only
│   │   ├── fishbowl/         # 34 source tables
│   │   └── magento/          # 25 source tables
│   ├── silver/               # 78 view models
│   │   ├── fishbowl/         # 34 models (ERP data)
│   │   ├── magento/          # 23 models (e-commerce data)
│   │   └── inventory/        # 21 models (quantity calculations)
│   └── gold/                 # 10 table models + 7 intermediate views
│       ├── intermediate/     # 7 reusable view models
│       │   ├── int_fishbowl_order_cost.sql
│       │   ├── int_fishbowl_product_enrichment.sql
│       │   ├── int_magento_order_freight.sql
│       │   ├── int_magento_product_attributes.sql
│       │   ├── int_magento_product_conversion.sql
│       │   ├── int_magento_product_eav_lookups.sql
│       │   └── int_magento_product_taxonomy.sql
│       ├── d_customer.sql
│       ├── d_customer_segmentation.sql
│       ├── d_product.sql
│       ├── d_product_bundle.sql
│       ├── d_store.sql
│       ├── d_vendor.sql
│       ├── f_inventoryview.sql
│       ├── f_pos.sql
│       ├── f_sales.sql
│       └── f_shippment.sql
├── seeds/
├── snapshots/
└── analyses/
docs/
├── snowflake_access_setup.md   # Snowflake roles, warehouses, RSA key-pair setup
└── AUDIT_BACKLOG.md            # Audit findings, backlog, and prioritized roadmap
```

**Counts:** 95 models (34 Fishbowl + 23 Magento + 21 Inventory + 10 Gold + 7 Intermediate), 59 source tables, 16 generic tests, 1 macro

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

### Fishbowl (34 tables)
Inventory management / ERP system. Key tables: `so`, `soitem`, `product`, `part`, `vendor`, `ship`, `po`, `poitem`, `receipt`, `receiptitem`, `uomconversion`, `kititem`, `objecttoobject`

### Magento (25 tables)
E-commerce platform. Key tables: `sales_order`, `sales_order_item`, `customer_entity`, `catalog_product_entity`, `quote`, `store`, EAV attribute tables (`eav_attribute`, `catalog_product_entity_varchar/int/text/decimal`)

### Source Freshness
Both sources have freshness configured: warn after 24h, error after 48h, using `_airbyte_extracted_at` as the loaded_at_field.

### EAV Pattern
Magento uses Entity-Attribute-Value for product attributes. Product attributes are resolved in `int_magento_product_eav_lookups.sql` and `int_magento_product_attributes.sql`, then consumed by `d_product.sql`. Attribute IDs are configured as dbt variables with prefix `ammodepot_magento_attr_id_*`.

---

## Common Commands

All commands run from `projects/ammodepot/`:

```bash
# Development (via uv)
uv run dbt deps --profiles-dir .           # Install packages
uv run dbt debug --profiles-dir .          # Test connection
uv run dbt parse --profiles-dir .          # Validate SQL/YAML (no connection needed)
uv run dbt build --profiles-dir .          # Run all models + tests
uv run dbt build --profiles-dir . --select +f_sales   # Run f_sales with upstream deps
uv run dbt test --profiles-dir . --select gold        # Test gold layer only
uv run dbt source freshness --profiles-dir .          # Check source freshness

# Linting
uv run sqlfluff lint models/               # Lint all models
uv run sqlfluff fix models/                # Auto-fix (review changes before committing)
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

9. **Snowflake migration** -- Migrating from Redshift to Snowflake. Snowflake uses `AD_AIRBYTE` database with `AIRBYTE_ROLE` (ingestion, OWNERSHIP) and `TRANSFORMER_ROLE` (dbt, owns SILVER/GOLD schemas). Service accounts use RSA key-pair auth (TYPE=SERVICE, no passwords). Shared `ETL_WH` warehouse (XSMALL).

10. **No column removals/renames without Power BI coordination** -- Gold layer tables are consumed directly by Power BI dashboards. Any column removal, rename, or type change requires coordinated BI update. See `docs/AUDIT_BACKLOG.md` for deferred items.

---

## Build & Deployment Status

- **dbt-core**: 1.11.6 with dbt-redshift 1.10.1
- **dbt Cloud**: Scheduled runs on Redshift (production), 88 of 95 models selected
- **Last local build**: PASS=402, WARN=32, ERROR=0, SKIP=0, TOTAL=434
- **Audit score**: 8.0/10 (see `docs/AUDIT_BACKLOG.md` for details)
- **Audit backlog**: 4 HIGH items, 6 MEDIUM items, 3 LOW items pending

---

## Agent Usage Guidelines

43 specialized agents organized by category in `.claude/agents/`:

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
| **Exploration** | codebase-explorer, kb-architect | Codebase analysis, knowledge base management |
| **Workflow** | build-agent, define-agent, design-agent, iterate-agent, ship-agent, brainstorm-agent | SDD pipeline stages |
| **Dev** | prompt-crafter, dev-loop-executor | PROMPT.md creation, Dev Loop execution |

### Most Relevant for This Project

- **dbt-expert** -- dbt model development, testing, and debugging
- **snowflake-expert** -- Snowflake queries, architecture (for migration evaluation)
- **medallion-architect** -- Bronze/Silver/Gold layer design
- **code-reviewer** -- Post-change code quality review
- **the-planner** -- Multi-step implementation planning

---

## Knowledge Base

KB domains in `.claude/kb/` across 6 categories:

| Category | Domains | Key Topics |
|---|---|---|
| **AI/ML** | Gemini, OpenRouter, CrewAI, LangFuse, Pydantic, Langflow | LLM platforms, multi-agent, observability, validation |
| **Automation** | n8n, Zapier, Mermaid | Workflow automation, diagramming |
| **Cloud** | AWS (S3, Athena, Glue, IAM, KMS, CloudWatch, Secrets Manager, S3 Tables), Azure, Multi-Cloud Patterns, GCP | AWS/Azure/GCP services |
| **Data Engineering** | Snowflake, dbt-core, dbt-cloud, Airbyte, Dagster, BigQuery, Airflow, Kafka, Apache Iceberg, Data Vault, Elementary, Great Expectations, Soda, FinOps, Data Contracts, Data Quality, Data Governance, OpenMetadata, Flake8 | Platforms, transformation, quality, governance, streaming |
| **DevOps/SRE** | Terraform, Terragrunt, Docker, Kubernetes, Grafana, Prometheus, Datadog, GitHub Actions, GitLab CI, Railway, uv, GitHub | IaC, containers, monitoring, CI/CD, tooling |
| **Document Processing** | Docling | Document parsing |

---

## Commands

14 slash commands in `.claude/commands/`:

| Command | Purpose |
|---|---|
| `/memory` | Save session insights to persistent memory |
| `/sync-context` | Analyze codebase and update CLAUDE.md |
| `/readme-maker` | Generate README.md from codebase analysis |
| `/create-kb` | Create new Knowledge Base domain |
| `/review` | Code review with quality analysis |
| `/build` | Build/implement features (SDD workflow) |
| `/define` | Define requirements and specs |
| `/design` | Design architecture and approach |
| `/iterate` | Iterate on existing implementation |
| `/brainstorm` | Brainstorm ideas and approaches |
| `/ship` | Ship/deploy changes |
| `/create-pr` | Create pull request |
| `/dev` | Dev Loop command (Level 2 agentic) |
| `/create-agent` | Create new specialized agent |

---

## MCP Tools Available

| MCP Server | Purpose |
|---|---|
| upstash-context-7-mcp | KB context storage and retrieval |
| exa | Code context search (web) |
| context7 | Library documentation lookup |
| n8n-mcp | n8n workflow automation |
| ref-tools-ref-tools-mcp | Reference tools |
