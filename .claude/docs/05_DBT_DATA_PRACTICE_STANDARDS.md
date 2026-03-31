# Section 5: dbt Data Practice Standards

> **Delivery Standards** — trinityBI Engineering
>
> Last updated: 2026-03-30

---

**Scope**: This document defines universal standards for dbt projects based on evidence from production systems. It is project-agnostic — business rules are handled separately per client. Every rule is grounded in real patterns or real failures.

**Relationship to other standards:**
- **SQL formatting**: See `.claude/rules/sql-standards.md` (no SELECT *, 80-char lines, snake_case, CTE conventions)
- **Git workflow**: See `.claude/docs/04_GIT_AND_WORKFLOW.md` (branching, commits, CI gates, environments)
- **dbt KB**: See `.claude/kb/data-engineering/transformation/dbt-core/` for implementation patterns

---

## 5.1 Architecture Decision Tree

### When to Use Each Architecture

```text
New project?
├── Analytical reporting + dashboards?
│   ├── < 50 sources, single domain → Medallion (Bronze/Silver/Gold)
│   └── > 50 sources, multiple domains → Medallion + Domain Marts
├── Audit trail + historical tracking required?
│   └── → Medallion + Snapshots (SCD Type 2)
├── Multiple source systems, high change velocity, need for auditability?
│   └── → Data Vault 2.0
├── Cost-sensitive, < 100GB, batch analytics?
│   └── → DuckDB + Iceberg (lakehouse)
└── Large scale, real-time + batch, enterprise BI?
    └── → Snowflake-native Medallion
```

### Medallion Architecture (Default)

The default for all new projects. Three layers with strict responsibilities:

| Layer | Schema | Materialization | Responsibility |
|-------|--------|-----------------|----------------|
| **Bronze** | `{target}_bronze` | `view` | 1:1 with source. `source()` only here. Rename, cast, filter deletes. No joins. |
| **Silver** | `{target}_silver` | `table` / `incremental` | Business logic, joins, dedup, aggregation. Organized by domain. |
| **Gold** | `{target}_gold` | `table` / `incremental` | Consumption-ready. Wide, denormalized entities. Plain names (`orders`, not `gold_orders`). |
| **Intermediate** | `{target}_intermediate` | `ephemeral` / `view` | Purpose-built transforms between Silver and Gold. Never exposed to consumers. |

#### Schema Routing

Every project must implement `generate_schema_name`:

```sql
-- macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'dev' -%}
        {{ target.schema }}
    {%- elif custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name }}
    {%- endif -%}
{%- endmacro %}
```

> **Evidence**: Both production projects use this macro. Dev gets a single flat schema (`DBT_DEV`) for easy cleanup; prod gets layer-separated schemas (`DBT_PROD_bronze`, `DBT_PROD_silver`, `DBT_PROD_gold`).

#### Materialization Escalation

```text
1. Start with VIEW (always current, no storage cost)
     ↓ query too slow for consumers or downstream models
2. Switch to TABLE (fast reads, full rebuild each run)
     ↓ build time too long or data volume growing
3. Switch to INCREMENTAL (process only new/changed data)
     ↓ time-series data with reliable event_time column
4. Consider MICROBATCH (dbt 1.9+, auto-backfill, batch retries)
```

> 📏 **Revisit signal**: When a view-materialized model appears in >3 downstream models and query time exceeds 30 seconds.

### Medallion + Snapshots

**When**: Business requires historical state tracking (SCD Type 2) — e.g., customer status changes, price history, subscription state.

Add snapshots alongside Medallion:
```text
Bronze → Silver → Snapshots (SCD2) → Gold
```

**Implementation**: Use dbt snapshots with `check_cols` or `updated_at` strategy. Snapshots read from Silver, not Bronze.

> 📏 **Revisit signal**: When you need to answer "what was the value of X on date Y?" and the source system doesn't provide history.

### Data Vault 2.0

**When**: Multiple source systems feeding the same business entities, high schema change velocity, strong audit requirements, or regulatory compliance demands full traceability.

| Component | Purpose | Materialization |
|-----------|---------|-----------------|
| Hub | Business keys | `incremental` (insert-only) |
| Link | Relationships between hubs | `incremental` (insert-only) |
| Satellite | Descriptive attributes + history | `incremental` (insert-only) |
| Point-in-Time (PIT) | Snapshot of current state for joins | `table` |
| Bridge | Pre-joined paths for performance | `table` |

**dbt implementation**: Use `dbtvault` package for hub/link/satellite generation.

```yaml
# packages.yml
packages:
  - package: Datavault-UK/dbtvault
    version: [">=0.10.0", "<0.11.0"]
```

**Folder structure**:
```text
models/
├── raw_vault/
│   ├── hubs/
│   ├── links/
│   └── satellites/
├── business_vault/
│   ├── pit/
│   └── bridge/
└── marts/
```

**Trade-offs vs Medallion**:
- **Pro**: Full audit trail, handles schema changes gracefully, insert-only (no updates)
- **Con**: Higher complexity, more models, requires PIT/Bridge tables for usable queries, steeper learning curve
- **Break-even**: Justified when >5 source systems feed the same entity or when regulatory audit is a hard requirement

> 📏 **Revisit signal**: When you have >5 source systems, or when schema changes from external sources break Silver models more than once per quarter.

### Hybrid DuckDB + Iceberg + Snowflake

**When**: Cost-sensitive workloads where Snowflake compute is disproportionate to value, batch analytics on structured data <100GB, or development/testing acceleration.

**Architecture**:
```text
Sources → Iceberg (S3) → DuckDB (local/ECS compute) → Iceberg (S3) → Snowflake (BI layer)
                           Bronze + Silver transforms        Gold consumption
```

**How it works**:
1. Raw data lands in S3 as Iceberg tables (via Airbyte, Fivetran, or custom ingestion)
2. DuckDB reads Iceberg, performs Bronze→Silver transforms, writes back to Iceberg
3. Snowflake External Tables or Iceberg Catalog reads Gold Iceberg tables for BI consumption
4. dbt orchestrates via `dbt-duckdb` adapter for transforms, `dbt-snowflake` for Gold layer

**Cost comparison** (approximate, <100GB):
| Component | Snowflake-Only | DuckDB+Iceberg Hybrid |
|-----------|----------------|----------------------|
| Compute (transforms) | ~$200-500/mo (XS warehouse) | ~$5-20/mo (ECS Fargate or local) |
| Storage | Included in Snowflake | ~$2-5/mo (S3) |
| BI queries | Included | ~$50-100/mo (Snowflake External Tables) |
| **Total** | **~$200-500/mo** | **~$60-125/mo** |

**Trade-offs**:
- **Pro**: 60-80% cost reduction for small-medium workloads, no vendor lock-in on transforms, faster local dev
- **Con**: Two adapters to maintain, no real-time capability, Iceberg catalog management overhead, limited ecosystem tooling
- **Break-even**: Justified when monthly Snowflake compute exceeds $300/mo AND workload is batch-only

**dbt multi-adapter setup**:
```yaml
# profiles.yml (conceptual — use environment variables)
my_project:
  target: dev
  outputs:
    dev_duckdb:
      type: duckdb
      path: /tmp/dev.duckdb
      extensions: [iceberg, httpfs]
    prod_snowflake:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
```

> 📏 **Revisit signal**: When Snowflake monthly compute exceeds $300/mo on a workload that is 100% batch, or when local development cycle exceeds 5 minutes per `dbt build`.

---

## 5.2 dbt Conventions

### Model Naming

#### Classification: 🔒 Universal

| Layer | Pattern | Example | Folder |
|-------|---------|---------|--------|
| **Bronze** | `bronze_{source}__{entity}` | `bronze_amazon_sp__orders` | `models/bronze/{source}/` |
| **Silver** | `silver_{domain}__{entity}` | `silver_sales__amazon_orders` | `models/silver/{domain}/` |
| **Gold** | `{entity}` (no prefix) | `orders`, `customers`, `inventory_velocity` | `models/gold/{domain}/` |
| **Intermediate** | `int_{entity}_{verb}` | `int_payments_pivoted_to_orders` | `models/intermediate/{domain}/` |

**Why**: Layer prefix in Bronze/Silver prevents ambiguity across schemas. Gold uses plain names because it's the consumer-facing layer — nobody wants to query `gold_sales__orders`.

> 📏 **Revisit signal**: If using dbt Semantic Layer, Gold naming may shift to `fct_`/`dim_` convention.

### Column Naming

#### Classification: 🔒 Universal

| Type | Convention | Example |
|------|-----------|---------|
| Primary key | `{entity}_id` | `order_id`, `customer_id` |
| Foreign key | `{referenced_entity}_id` | `customer_id` in orders table |
| Boolean | `is_{state}` or `has_{thing}` | `is_active`, `has_discount` |
| Date | `{event}_date` | `order_date`, `ship_date` |
| Timestamp | `{event}_at` (always UTC) | `created_at`, `updated_at` |
| Amount/money | `{thing}_{unit}` | `total_usd`, `shipping_cost` |
| Count | `{thing}_count` | `order_count`, `item_count` |
| Ratio/pct | `{thing}_pct` or `{thing}_ratio` | `discount_pct`, `conversion_ratio` |

**All columns are snake_case, all lowercase.** No exceptions for new projects.

> ⚠️ **Legacy exception**: UPPER_CASE Gold columns exist in one production project for Power BI backward compatibility. This is tech debt with a migration path (see Section 5.10). New projects must not replicate this.

### Configuration Placement

#### Classification: 📐 Pattern (condition: project size)

**Hybrid approach**: Directory-level defaults in `dbt_project.yml`, per-model overrides via `config()` block only when deviating.

```yaml
# dbt_project.yml — directory-level defaults
models:
  my_project:
    bronze:
      +materialized: view
      +schema: bronze
    silver:
      +materialized: table
      +schema: silver
    gold:
      +materialized: table
      +schema: gold
      +transient: true  # Snowflake: skip Time Travel for Gold tables
```

```sql
-- Only use config() block when overriding the directory default
{{
    config(
        materialized = 'incremental',
        unique_key = 'order_id',
        incremental_strategy = 'merge'
    )
}}
```

**Why**: Centralizing defaults in `dbt_project.yml` makes the materialization strategy visible in one place. Per-model `config()` is reserved for exceptions — this makes exceptions immediately visible when reading a model.

### Macro Conventions

#### Classification: 🔒 Universal

- **DRY**: If a calculation appears in 2+ models, extract to a macro
- **Naming**: `{domain}_{action}` — e.g., `reorder_estimated_date`, `sales_calculate_net`
- **Location**: `macros/{domain}/` or `macros/cross_db/` for adapter-specific logic
- **Cross-db dispatch**: Use `adapter.dispatch` when supporting multiple warehouses

```sql
-- macros/cross_db/convert_tz.sql
{% macro convert_tz(column, from_tz, to_tz) %}
    {{ return(adapter.dispatch('convert_tz')(column, from_tz, to_tz)) }}
{% endmacro %}

{% macro snowflake__convert_tz(column, from_tz, to_tz) %}
    convert_timezone('{{ from_tz }}', '{{ to_tz }}', {{ column }})
{% endmacro %}
```

> **Evidence**: orchestration-hub uses 7 domain macros (reorder calculations). ammodepot uses 4 cross-db dispatch macros (Redshift→Snowflake migration). Both approaches are valid.

### Variable Usage

#### Classification: 🔒 Universal

**Rule**: No hardcoded business values in SQL. Use `var()` with defaults in `dbt_project.yml`.

```yaml
# dbt_project.yml
vars:
  lookback_days: 3
  safety_stock_days: 14
  source_freshness_warn_hours: 24
  source_freshness_error_hours: 48
```

```sql
-- In model
where order_date >= dateadd(day, -{{ var('lookback_days') }}, current_date())
```

**Why**: Parameterized values are auditable, searchable, and changeable without touching SQL. Both production projects achieve 100% compliance on this.

---

## 5.3 Testing and Documentation

### Minimum Test Requirements

#### Classification: 🔒 Universal

Every model must pass these tests before merge:

| Model Type | Required Tests |
|------------|----------------|
| **Every model** | `unique` + `not_null` on primary key |
| **Every FK column** | `relationships` (severity: warn if orphans expected) |
| **Every status/enum** | `accepted_values` |
| **Every Gold model** | At least 1 business logic assertion (range, expression, or custom) |
| **Every source** | Freshness check (`loaded_at_field` configured) |

### Severity Pyramid

#### Classification: 🔒 Universal

| Layer | Default Severity | Override When |
|-------|-----------------|---------------|
| **Gold** | `error` | Never — Gold failures block deployment |
| **Silver** | `error` for PKs/FKs, `warn` for business rules | Promote to `error` when business logic is validated |
| **Bronze** | `warn` | Promote PKs to `error` once source quality is established |
| **Sources** | `warn` (freshness), `error` (PK uniqueness) | — |

```yaml
# Example: Gold model with severity pyramid
models:
  - name: orders
    columns:
      - name: order_id
        data_tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: total_amount
        data_tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000
              config:
                severity: error
```

> **Evidence**: Both production projects enforce this pyramid. orchestration-hub uses `dbt_expectations` for range validation. ammodepot uses custom generic tests (`assert_non_negative_values`, `assert_valid_email_format`).

### Store Failures

#### Classification: 📐 Pattern (condition: Gold models)

```yaml
# Enable store_failures for Gold model tests
models:
  - name: orders
    data_tests:
      - unique:
          config:
            severity: error
            store_failures: true  # Saves failing rows to audit schema
```

**Why**: When a Gold test fails, you need the failing rows immediately. `store_failures` writes them to a table in the test schema for debugging.

### Unit Tests (dbt 1.8+)

#### Classification: 📐 Pattern (condition: complex Gold transformations)

**Rule**: Add unit tests to any Gold model with >50 lines of transformation logic or conditional business rules.

```yaml
unit_tests:
  - name: test_net_sales_calculation
    model: daily_sku_sales
    given:
      - input: ref('silver_sales__amazon_orders')
        rows:
          - {order_id: 1, quantity: 2, item_price: 10.00, discount: 1.50}
    expect:
      rows:
        - {net_sales: 18.50}
```

**Why**: Unit tests validate transformation logic without hitting the warehouse. They catch regressions when refactoring complex business rules.

> 📏 **Revisit signal**: When unit test coverage exists for all Gold models with >50 lines of logic.

### Documentation Requirements

#### Classification: 🔒 Universal

| Asset | Minimum Documentation |
|-------|----------------------|
| **Every model** | `description` in schema YAML |
| **Every Gold column** | `description` explaining business meaning |
| **Every source** | `description` + `loaded_at_field` for freshness |
| **Every macro** | Jinja comment block at top: purpose, params, return |
| **Every exposure** | `description`, `owner`, `maturity`, `depends_on` |

**YAML file naming**:
- Sources: `_{source_group}__sources.yml` alongside Bronze models
- Models: `_{domain}__models.yml` alongside models in same folder

### Data Contracts (dbt 1.9+)

#### Classification: 📐 Pattern (condition: Gold models consumed by external systems)

```yaml
models:
  - name: orders
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: varchar
        constraints:
          - type: not_null
          - type: primary_key
      - name: total_amount
        data_type: number(18,2)
```

**Why**: Contracts prevent accidental schema changes from breaking downstream consumers (BI tools, APIs, reverse ETL). The contract fails the build if column names, types, or constraints change.

> 📏 **Revisit signal**: Enable on all Gold models once dbt 1.9+ is adopted across all projects.

---

## 5.4 Observability

### Source Freshness

#### Classification: 🔒 Universal

Every source table must have freshness configured:

```yaml
sources:
  - name: raw_orders
    database: "{{ env_var('SOURCE_DATABASE') }}"
    schema: raw
    loaded_at_field: _airbyte_extracted_at  # or _fivetran_synced
    freshness:
      warn_after:
        count: 24
        period: hour
      error_after:
        count: 48
        period: hour
    tables:
      - name: orders
```

**Why**: Source freshness is the earliest detection point for ingestion failures. The 24h/48h thresholds are calibrated for daily batch pipelines — adjust for higher-frequency pipelines.

> 📏 **Revisit signal**: When any pipeline runs more frequently than daily, tighten thresholds to match the expected cadence.

### SLA Framework

#### Classification: 📐 Pattern (condition: consumer-facing Gold models)

| Layer | SLA | Measurement |
|-------|-----|-------------|
| **Gold** | Data available by T+4h (4 hours after midnight UTC) | `dbt_expectations.expect_row_values_to_have_recent_data` |
| **Silver** | No consumer-facing SLA; covered by Gold SLA | — |
| **Bronze** | Governed by source freshness checks | Source freshness config |

```yaml
# Recency test for Gold model
models:
  - name: orders
    data_tests:
      - dbt_expectations.expect_row_values_to_have_recent_data:
          datepart: day
          interval: 3
          config:
            severity: error
```

### Exposures

#### Classification: 🔒 Universal (for Gold models with known consumers)

Every Gold model consumed by an external system must have an exposure:

```yaml
# models/gold/_exposures.yml
exposures:
  - name: sales_dashboard
    type: dashboard
    maturity: high
    owner:
      name: Analytics Team
      email: analytics@company.com
    description: "Daily sales dashboard in Power BI"
    depends_on:
      - ref('orders')
      - ref('customers')
      - ref('daily_sku_sales')
    url: https://app.powerbi.com/groups/.../dashboards/...
```

**Why**: Exposures document the blast radius of a model change. Without them, you cannot answer "who breaks if I change this column?"

> **Evidence**: ammodepot has 5 exposures documenting Power BI + Streamlit consumers. orchestration-hub is missing exposures (tech debt — see Section 5.10).

### Artifact Persistence

#### Classification: 📐 Pattern (condition: production deployments)

Persist `manifest.json` and `run_results.json` after every production run:

```bash
# Post-run: upload artifacts to S3 or GCS
dbt run && \
  aws s3 cp target/manifest.json s3://dbt-artifacts/$(date +%Y-%m-%d)/manifest.json && \
  aws s3 cp target/run_results.json s3://dbt-artifacts/$(date +%Y-%m-%d)/run_results.json
```

**Why**: Historical artifacts enable `state:modified` slim CI, trend analysis on build times, and post-incident debugging.

---

## 5.5 Ingestion and Sources

### Source Declaration

#### Classification: 🔒 Universal

Every raw table gets a `sources.yml` entry. No exceptions.

```yaml
# models/bronze/_shopify__sources.yml
sources:
  - name: shopify
    database: "{{ env_var('FIVETRAN_DATABASE') }}"
    schema: shopify
    loaded_at_field: _fivetran_synced
    freshness:
      warn_after: { count: 24, period: hour }
      error_after: { count: 48, period: hour }
    tables:
      - name: orders
        description: "Shopify orders, synced via Fivetran"
        columns:
          - name: id
            data_tests:
              - unique
              - not_null
```

### CDC Filtering Standard

#### Classification: 📐 Pattern (condition: CDC-enabled sources like Airbyte)

When using CDC ingestion, Bronze models must filter deleted rows and deduplicate:

```sql
-- models/bronze/fishbowl/bronze_fishbowl__orders.sql
with source as (
    select
        id,
        order_number,
        customer_id,
        status,
        total_amount,
        created_at,
        _ab_cdc_updated_at,
        _airbyte_extracted_at
    from {{ source('fishbowl', 'orders') }}
    where _ab_cdc_deleted_at is null
)

select *
from source
qualify row_number() over (
    partition by id
    order by coalesce(_ab_cdc_updated_at, _airbyte_extracted_at) desc nulls last
) = 1
```

**Why**: CDC sources contain delete markers and duplicate versions of the same row. Filtering and dedup must happen in Bronze (the data cleaning layer), not Silver.

> **Evidence**: ammodepot applies this pattern across all 55 Fishbowl+Magento Silver models. The standard moves this logic to Bronze where it belongs.

### Ingestion Tool Agnosticism

#### Classification: 🔒 Universal

**Rule**: The dbt layer must be decoupled from the ingestion tool. Reference ingestion-specific columns (`_fivetran_synced`, `_airbyte_extracted_at`) only in Bronze models and source freshness configs — never in Silver or Gold.

**Why**: Changing ingestion tools (e.g., Fivetran → Airbyte) should only require updating Bronze models and source YAML, not the entire transformation layer.

### Credentials

#### Classification: 🔒 Universal

- `profiles.yml` is never committed to git (add to `.gitignore`)
- All credentials via environment variables or secret managers
- Snowflake: RSA key pair authentication (no passwords)
- Service accounts per tool: `SVC_DBT`, `SVC_FIVETRAN`, `SVC_AIRBYTE`

---

## 5.6 Multi-Tenancy

### Isolation Strategies

#### Classification: 📐 Pattern (condition: multi-client deployments)

Two approved patterns:

| Strategy | When to Use | How |
|----------|-------------|-----|
| **Database isolation** | Regulatory/compliance, different source systems per client | Separate Snowflake database per client. dbt project shared, `--vars` or `dbt_project.yml` overrides per client |
| **Schema isolation** | Cost optimization, similar source systems across clients | Same database, different schemas per client. `generate_schema_name` macro routes by `target.name` or `var('client')` |

**Decision matrix**:

```text
Need regulatory isolation?
├── Yes → Database isolation
└── No
    ├── Different source systems per client? → Database isolation
    └── Same source systems? → Schema isolation
```

### Monorepo Structure

#### Classification: 📐 Pattern (condition: >1 client)

```text
project_root/
├── clients/
│   ├── client_a/
│   │   └── dbt_project/    # Client-specific dbt_project.yml, models
│   └── client_b/
│       └── dbt_project/
├── shared/
│   └── dbt_macros/          # Shared macros across clients
└── orchestration/           # Dagster/Airflow/ECS definitions
```

**Why**: Each client gets isolated models and config while sharing macros and orchestration infrastructure.

> **Evidence**: orchestration-hub uses this structure (TheraICE active, Apothca onboarding). Database isolation via separate Snowflake databases per client.

### Anti-pattern: tenant_id Column

#### Classification: ❌ DO NOT USE (unless explicitly justified)

**Do not** add a `tenant_id` column to every table. This approach:
- Adds query complexity (every query needs `WHERE tenant_id = ...`)
- Creates security risk (accidental cross-tenant data exposure)
- Increases storage and compute (unnecessary column in every row)
- Complicates RBAC (row-level security instead of object-level)

Use database or schema isolation instead.

> 📏 **Revisit signal**: Only if you need cross-tenant analytics (e.g., benchmarking) — and even then, use a separate aggregated model, not tenant_id in every table.

---

## 5.7 Costs

### Orchestrator Comparison

#### Classification: 📐 Pattern (condition: new project setup)

| Orchestrator | Monthly Cost | Best For | Trade-off |
|-------------|-------------|----------|-----------|
| **ECS Fargate Spot** | ~$4/mo | Solo/small team, simple schedules | No UI, manual monitoring, DIY alerting |
| **Dagster Cloud Serverless** | ~$100/mo base | Team collaboration, complex DAGs, CDC sensors | Higher cost, vendor dependency |
| **dbt Cloud** | ~$660/mo (Team plan) | dbt-first teams, built-in IDE | Highest cost, limited orchestration flexibility |
| **GitHub Actions** | Free (public) / ~$10-50/mo | CI/CD-only, no persistent orchestration | No state, no sensors, no scheduling UI |

> **Evidence**: ammodepot runs on ECS Fargate at $3.70/mo (replaced $663/mo dbt Cloud). orchestration-hub uses Dagster Cloud for CDC sensors and team collaboration.

**Decision**: Choose based on team size and operational tolerance, not just license cost. A solo practitioner gets more value from $4/mo ECS than $100/mo Dagster. A team of 3+ benefits from Dagster's collaboration features.

### Warehouse Sizing (Snowflake)

#### Classification: 🔒 Universal

| Workload | Warehouse Size | Auto-Suspend | Why |
|----------|---------------|-------------|-----|
| dbt transforms | X-Small | 60 seconds | dbt runs are sequential within a thread; larger warehouses don't help |
| BI queries (Power BI, Looker) | X-Small | 60 seconds | Interactive queries are typically simple aggregations |
| Airbyte/Fivetran ingestion | X-Small | 60 seconds | Ingestion is I/O-bound, not compute-bound |
| Heavy ad-hoc analytics | Small-Medium | 300 seconds | Only if analysts run complex queries regularly |

**Rule**: Start X-Small. Upgrade only when you have query_tag data proving the bottleneck is compute, not query design.

### Materialization Cost Impact

#### Classification: 🔒 Universal

| Materialization | Storage Cost | Compute Cost | When |
|----------------|-------------|-------------|------|
| `view` | $0 | On every read | Bronze layer, low-fan-out models |
| `table` | Per GB stored | Full rebuild each run | Silver/Gold, moderate data |
| `incremental` | Per GB stored | Only new/changed data | Large tables (>1M rows), reliable timestamps |
| `ephemeral` | $0 | Inlined into downstream | Intermediate computations consumed by 1-2 models |
| `transient: true` | Reduced (no Time Travel) | Same as table | Gold tables where historical snapshots aren't needed |

### Cost Attribution

#### Classification: 📐 Pattern (condition: Snowflake)

Tag every model for cost tracking:

```yaml
# dbt_project.yml
models:
  my_project:
    +query_tag: "dbt"
    gold:
      +query_tag: "dbt:gold"
    silver:
      +query_tag: "dbt:silver"
    bronze:
      +query_tag: "dbt:bronze"
```

Query cost attribution:
```sql
-- Snowflake: cost by dbt layer
select
    split_part(query_tag, ':', 2) as layer,
    sum(credits_used_cloud_services) as credits
from snowflake.account_usage.query_history
where query_tag like 'dbt%'
    and start_time >= dateadd(month, -1, current_timestamp())
group by 1
order by 2 desc;
```

### DuckDB + Iceberg Cost Evaluation

#### Classification: 📐 Pattern (condition: monthly Snowflake compute >$300)

**Evaluation framework** — when to consider offloading compute:

| Signal | Threshold | Action |
|--------|-----------|--------|
| Monthly Snowflake compute | >$300/mo | Evaluate DuckDB for Bronze/Silver transforms |
| Data volume | <100GB | DuckDB handles comfortably |
| Workload type | 100% batch | No real-time requirement for DuckDB |
| Query complexity | Aggregations, joins, window functions | DuckDB excels at analytical SQL |
| Dev cycle time | >5 min per `dbt build` | DuckDB local dev is near-instant |

**Migration path**:
1. Start with local DuckDB for development (`dbt-duckdb` adapter)
2. Validate transforms produce identical results to Snowflake
3. Move Bronze+Silver to DuckDB on ECS/Lambda writing Iceberg to S3
4. Keep Gold on Snowflake (External Tables reading Iceberg)
5. Monitor cost savings for 1 month before committing

> 📏 **Revisit signal**: When monthly Snowflake bill exceeds $300 on batch-only workloads, or when DuckDB 1.2+ ships production-grade Iceberg write support.

---

## 5.8 CI/CD and Operations

### dbt CI Gates

#### Classification: 🔒 Universal

Every PR touching `models/`, `macros/`, `dbt_project.yml`, or `packages.yml` must pass:

| Gate | Tool | What It Catches |
|------|------|-----------------|
| SQL lint | sqlfluff | Formatting, naming, anti-patterns |
| YAML/SQL parse | `dbt parse` | Syntax errors, broken refs, invalid config |
| Python lint | flake8 | Orchestration code quality |
| Python tests | pytest | Orchestration unit/integration tests |
| dbt build (conditional) | `dbt build --target ci` | Model + test execution against warehouse |

> **Cross-reference**: See Section 4.5 in `.claude/docs/04_GIT_AND_WORKFLOW.md` for the full merge workflow and environment mapping.

### Slim CI

#### Classification: 📐 Pattern (condition: projects with incremental models)

```bash
# Step 1: Clone existing incremental models into CI schema
dbt clone --select state:modified+,config.materialized:incremental,state:old

# Step 2: Build only modified models (incrementals run incrementally, not full refresh)
dbt build --select state:modified+
```

**Why**: Without slim CI, modified incremental models trigger a full refresh in CI because the target table doesn't exist in the PR schema. Cloning avoids this.

> **Evidence**: Documented in dbt best practices. Not yet implemented in either production project (opportunity).

### Deployment Checklist

#### Classification: 🔒 Universal

Before merging to main:

- [ ] All CI gates green
- [ ] PR conversations resolved
- [ ] No new `SELECT *` introduced
- [ ] New models have schema YAML with descriptions
- [ ] New columns in Gold have descriptions
- [ ] Incremental models tested with `--full-refresh` at least once
- [ ] No hardcoded values (use `var()`)
- [ ] `CLAUDE.md` updated if conventions changed

### When to Full Refresh

#### Classification: 📐 Pattern (condition: incremental models)

| Scenario | Action |
|----------|--------|
| New incremental model (first deploy) | Automatic full refresh (no target table exists) |
| Schema change in incremental model | `dbt run --select model_name --full-refresh` |
| Suspected data drift | Compare incremental vs full refresh row counts |
| Source system backfilled historical data | Full refresh affected models |

### Operational Runbooks (Summary)

| Incident | First Response | Escalation |
|----------|---------------|------------|
| Source freshness failure | Check ingestion pipeline status → check source system | Contact source system owner |
| Gold test failure (error) | Triage: is it data quality or code regression? → `store_failures` table | Page on-call if consumer-facing |
| Gold test failure (warn) | Create ticket, investigate in next sprint | — |
| Incremental model drift | Run `--full-refresh` for affected model | If persists, review incremental logic |
| Build timeout | Check Snowflake query history for long-running queries | Consider materialization change |

---

## 5.9 Anti-Patterns

#### Classification: 🔒 Universal (all items)

| # | Anti-Pattern | Why It's Bad | Do Instead | Evidence |
|---|-------------|-------------|------------|----------|
| 1 | `SELECT *` anywhere except `select * from final` | Schema drift, broken lineage, wasted compute | Explicit column lists always | Both projects: 100% compliance |
| 2 | UPPER_CASE columns in Gold | BI tool dictating data model, naming inconsistency | snake_case universally; configure BI tool aliases | ammodepot legacy (Power BI) |
| 3 | Hardcoded business values in SQL | Impossible to audit, scattered across models | `var()` with defaults in `dbt_project.yml` | Both projects: zero hardcoded values |
| 4 | No Bronze/staging layer | Silver conflates source cleaning AND business logic | Add Bronze: 1:1 with source, `source()` only here | ammodepot: Silver does both |
| 5 | Intermediate models in Gold schema | Pollutes consumer namespace, confuses BI tools | Own schema: `{target}_intermediate` | ammodepot: 9 int_ models in Gold |
| 6 | `source()` outside Bronze | Multiple entry points for raw data, broken lineage | `source()` only in Bronze models | dbt best practice |
| 7 | Joins in Bronze/staging | Duplicated logic, unclear lineage | Move joins to Silver/intermediate | dbt best practice |
| 8 | Force-materializing everything as tables | Wasted storage and compute | Follow materialization escalation (view→table→incremental) | dbt best practice |
| 9 | Magic numbers in SQL | Unauditable business rules | `var()` with descriptive names and defaults | Both projects: parameterized |
| 10 | No data contracts on Gold | Schema changes silently break consumers | `contract: {enforced: true}` on Gold models | Neither project has contracts (debt) |

### Detailed Anti-Pattern: No Bronze Layer

> ⚠️ **DO NOT REPLICATE**

**What**: Silver models that directly reference `source()` and perform both source cleaning (CDC filtering, type casting, renaming) and business logic (joins, aggregations, calculations) in the same model.

**Why it's bad**:
- Violates Single Responsibility Principle — one model does two jobs
- Source cleaning logic is duplicated if multiple Silver models read the same source
- Changing ingestion tool requires modifying Silver models (tight coupling)
- Cannot test source cleaning independently from business logic

**Correct**:
```text
source() → Bronze (clean, rename, cast, dedup) → Silver (join, aggregate, calculate)
```

**Incorrect**:
```text
source() → Silver (clean + rename + cast + dedup + join + aggregate)
```

> 📏 **Revisit signal**: Never. Bronze layer is always justified.

### Detailed Anti-Pattern: Intermediate in Gold Schema

> ⚠️ **DO NOT REPLICATE**

**What**: Models prefixed with `int_` living in the Gold schema alongside consumer-facing tables.

**Why it's bad**:
- BI tools discover `int_` models and expose them to users
- Users cannot distinguish intermediate computations from final outputs
- Schema becomes cluttered with non-consumer models

**Fix**: Route intermediates to `{target}_intermediate` schema via `dbt_project.yml`:
```yaml
models:
  my_project:
    intermediate:
      +schema: intermediate
      +materialized: ephemeral  # or view if referenced by >1 Gold model
```

---

## 5.10 Active Technical Debt

> **Living registry** — update when debt is created or resolved. Last reviewed: 2026-03-30.

### 🔴 Critical

| # | Debt | Where | Impact | Remediation | Effort |
|---|------|-------|--------|-------------|--------|
| 1 | **No Bronze layer** — Silver models conflate source cleaning with business logic | dbt_ammodepot: all 76 Silver models | Source cleaning duplicated across Silver; ingestion tool change requires modifying Silver | Introduce Bronze SQL models (1:1 with source) for top 10 highest-traffic sources first, then migrate remaining | Partial refactor (2 weeks) |
| 2 | **UPPER_CASE Gold columns** — naming inconsistency across practice | dbt_ammodepot: all 22 Gold models | New projects cannot follow the snake_case standard while ammodepot diverges; Power BI queries hardcoded to UPPER_CASE | Create `rename_to_snake_case` macro; migrate 5 Gold models per sprint; update Power BI queries in parallel | Full migration (4-6 weeks) |

### 🟡 Important

| # | Debt | Where | Impact | Remediation | Effort |
|---|------|-------|--------|-------------|--------|
| 3 | **No dbt unit tests** | Both projects | No TDD for transformation logic; refactoring is high-risk | Add unit tests to 3 most complex Gold models per project | Point fix per model |
| 4 | **No dbt data contracts** | Both projects | Schema changes in Gold silently break downstream consumers | Add `contract: {enforced: true}` to all Gold models | Point fix (1 day per project) |
| 5 | **Intermediate models in Gold schema** | dbt_ammodepot: 9 `int_` models | BI tools discover intermediate tables; user confusion | Add `intermediate` schema routing in `dbt_project.yml` | Point fix (1 hour) |
| 6 | **No exposures** | dbt-orchestration-hub | Cannot assess blast radius of Gold model changes | Add exposure YAML for each Power BI dashboard | Point fix (2 hours) |
| 7 | **Hardcoded product classification** | dbt_ammodepot: `d_product.sql` (150+ lines of CASE statements) | Unauditable by non-technical users; changes require SQL deployment | Move classification to seed or reference table; d_product joins against it | Partial refactor (1 week) |

### 🟢 Minor

| # | Debt | Where | Impact | Remediation | Effort |
|---|------|-------|--------|-------------|--------|
| 8 | **Model count discrepancy in README** | dbt_ammodepot: README.md | Documentation inaccuracy | Update count to actual (98 models) | Point fix (5 min) |
| 9 | **Product classification not in CLAUDE.md** | dbt_ammodepot: CLAUDE.md | Undocumented business logic for future developers | Add 5-tier classification description to CLAUDE.md | Point fix (15 min) |

---

## 5.11 Action Plan (4 Weeks)

> Priority-ordered by: (1) data reliability, (2) cost impact, (3) development speed.

| Wk | # | Action | Repo | Effort | Depends On |
|----|---|--------|------|--------|------------|
| 1 | 1 | Publish this standards document | claude-code-lab | Done | — |
| 1 | 2 | Add exposures YAML for all BI dashboards | orchestration-hub | 2h | — |
| 1 | 3 | Create `.claude/rules/dbt-conventions.md` | claude-code-lab | 1h | #1 |
| 2 | 4 | Add `contract: {enforced: true}` to all Gold models | orchestration-hub | 4h | — |
| 2 | 5 | Introduce Bronze SQL models for top 10 ammodepot sources | dbt_ammodepot | 3d | — |
| 2 | 6 | Move intermediate models to `_intermediate` schema | dbt_ammodepot | 1h | — |
| 3 | 7 | Add dbt unit tests to 3 most complex Gold models (each) | both | 2d | — |
| 3 | 8 | Create `rename_to_snake_case` macro, migrate 5 Gold models | dbt_ammodepot | 3d | — |
| 4 | 9 | Add source freshness SLA documentation to all source YAMLs | both | 2h | — |
| 4 | 10 | Add `query_tag` config for Snowflake cost attribution | both | 1h | — |

---

## 5.12 Missing Components

> Items marked `[NEW]` were created alongside this document.

| # | Component | Path | Status |
|---|-----------|------|--------|
| 1 | This standards document | `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md` | [NEW] |
| 2 | dbt conventions rule (path-scoped) | `.claude/rules/dbt-conventions.md` | [NEW] |
| 3 | Data contracts KB pattern | `.claude/kb/data-engineering/transformation/dbt-core/patterns/data-contracts.md` | [NEW] |
| 4 | Multi-tenancy KB pattern | `.claude/kb/data-engineering/transformation/dbt-core/patterns/multi-tenancy.md` | [NEW] |
| 5 | Cross-reference in SQL standards | `.claude/rules/sql-standards.md` (updated) | [NEW] |

---

*Built from evidence across 2 production dbt projects (125+ models, 415+ tests). Every rule has a real-world justification.*
